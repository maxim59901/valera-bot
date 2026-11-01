import base64
import json
from pathlib import Path
from typing import Any, AsyncIterator

from ..config import Settings
from ..db import Database
from .comfyui import ComfyUIClient
from .ollama import OllamaClient
from .searxng import SearxngClient

WEB_SEARCH_TOOL = {
    "type": "function",
    "function": {
        "name": "web_search",
        "description": (
            "Search the live web for current facts, news, prices, sports, weather, "
            "or anything that may have changed after your training data. "
            "Call this automatically when freshness matters. Do not ask the user for permission."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Concise search query"},
            },
            "required": ["query"],
        },
    },
}

GENERATE_IMAGE_TOOL = {
    "type": "function",
    "function": {
        "name": "generate_image",
        "description": (
            "Generate an image from a text prompt. Call this automatically when the user "
            "asks to draw, paint, illustrate, design, or visualize something. "
            "Do not ask the user to switch modes."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Detailed English image prompt for the generator",
                },
                "negative_prompt": {
                    "type": "string",
                    "description": "Optional negative prompt",
                },
            },
            "required": ["prompt"],
        },
    },
}

AGENT_SYSTEM_SUFFIX = (
    "\n\nYou have tools and must use them autonomously when they help — like an agent, "
    "not a chatbot that asks permission. Rules:\n"
    "- Need fresh/real-world info → call web_search yourself, then answer.\n"
    "- User wants a picture/illustration → call generate_image yourself, then briefly comment.\n"
    "- Pure reasoning/coding/chat → answer directly, no tools.\n"
    "- You may chain tools (search then answer, or search then draw).\n"
    "- Never invent tool results. Never refuse a tool call just to stay in text mode."
)


def _sse(event: str, data: dict[str, Any]) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def _parse_args(raw_args: Any) -> dict[str, Any]:
    if isinstance(raw_args, str):
        try:
            parsed = json.loads(raw_args)
            return parsed if isinstance(parsed, dict) else {"query": raw_args}
        except json.JSONDecodeError:
            return {"query": raw_args, "prompt": raw_args}
    if isinstance(raw_args, dict):
        return raw_args
    return {}


class ChatEngine:
    def __init__(self, settings: Settings, db: Database) -> None:
        self.settings = settings
        self.db = db
        self.ollama = OllamaClient(settings)
        self.searx = SearxngClient(settings)
        self.comfy = ComfyUIClient(settings)

    def _history_to_ollama(self, messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        for m in messages:
            item: dict[str, Any] = {"role": m["role"], "content": m.get("content") or ""}
            images = m.get("images")
            if images:
                b64_list = []
                for img in images:
                    if isinstance(img, str) and img.startswith("data:"):
                        b64_list.append(img.split(",", 1)[-1])
                    elif isinstance(img, str) and not img.startswith("/") and Path(img).exists():
                        b64_list.append(base64.b64encode(Path(img).read_bytes()).decode("ascii"))
                    elif isinstance(img, str) and (img.startswith("/") or img.startswith("http")):
                        # Served media paths — skip for model text history; vision turn passes b64
                        continue
                    else:
                        b64_list.append(img)
                if b64_list:
                    item["images"] = b64_list
            out.append(item)
        return out

    def _tools(
        self,
        *,
        enable_search: bool,
        enable_image_gen: bool,
    ) -> list[dict[str, Any]] | None:
        tools: list[dict[str, Any]] = []
        if enable_search:
            tools.append(WEB_SEARCH_TOOL)
        if enable_image_gen:
            tools.append(GENERATE_IMAGE_TOOL)
        return tools or None

    async def stream_reply(
        self,
        chat_id: str,
        user_text: str,
        *,
        model: str | None = None,
        enable_search: bool | None = None,
        enable_image_gen: bool | None = None,
        system_prompt: str | None = None,
        image_paths: list[str] | None = None,
        image_b64: list[str] | None = None,
    ) -> AsyncIterator[str]:
        chat = await self.db.get_chat(chat_id)
        if not chat:
            yield _sse("error", {"message": "Chat not found"})
            return

        use_model = model or chat.get("model") or self.settings.default_model
        if image_paths or image_b64:
            use_model = model or self.settings.vision_model

        search_on = self.settings.enable_search if enable_search is None else enable_search
        image_on = self.settings.enable_image_gen if enable_image_gen is None else enable_image_gen
        base_prompt = system_prompt or self.settings.system_prompt
        prompt = base_prompt + AGENT_SYSTEM_SUFFIX

        stored_images: list[str] | None = image_paths or None
        if not stored_images and image_b64:
            stored_images = image_b64

        user_msg = await self.db.add_message(
            chat_id,
            "user",
            user_text,
            images=stored_images,
        )
        yield _sse("user_message", user_msg)

        if chat["title"] in ("New chat", "", None):
            title = user_text.strip().split("\n", 1)[0][:60] or "New chat"
            await self.db.update_chat(chat_id, title=title, model=use_model)
            yield _sse("chat_updated", {"id": chat_id, "title": title, "model": use_model})
        else:
            await self.db.update_chat(chat_id, model=use_model)

        history = await self.db.list_messages(chat_id)
        ollama_messages: list[dict[str, Any]] = [{"role": "system", "content": prompt}]
        ollama_messages.extend(self._history_to_ollama(history))

        if image_b64 and ollama_messages:
            last = ollama_messages[-1]
            if last.get("role") == "user" and not last.get("images"):
                last["images"] = image_b64

        tools = self._tools(enable_search=search_on, enable_image_gen=image_on)
        assistant_msg = await self.db.add_message(chat_id, "assistant", "")
        yield _sse("assistant_start", {"id": assistant_msg["id"]})

        full_text = ""
        assistant_images: list[str] = []
        search_meta: list[dict[str, Any]] = []
        tool_meta: list[dict[str, Any]] = []
        max_tool_rounds = 5

        try:
            for _round in range(max_tool_rounds + 1):
                tool_calls_acc: list[dict[str, Any]] = []
                content_acc = ""
                yield _sse("status", {"state": "thinking"})

                async for chunk in self.ollama.chat_stream(
                    model=use_model,
                    messages=ollama_messages,
                    tools=tools,
                ):
                    msg = chunk.get("message") or {}
                    piece = msg.get("content") or ""
                    if piece:
                        content_acc += piece
                        full_text += piece
                        yield _sse("token", {"content": piece})

                    if msg.get("tool_calls"):
                        tool_calls_acc = msg["tool_calls"]

                    if chunk.get("done"):
                        final_msg = chunk.get("message") or msg
                        if final_msg.get("tool_calls"):
                            tool_calls_acc = final_msg["tool_calls"]

                if not tool_calls_acc or not tools:
                    break

                ollama_messages.append(
                    {
                        "role": "assistant",
                        "content": content_acc,
                        "tool_calls": tool_calls_acc,
                    }
                )

                for call in tool_calls_acc:
                    fn = call.get("function") or {}
                    name = fn.get("name") or ""
                    args = _parse_args(fn.get("arguments"))

                    if name == "web_search" and search_on:
                        query = str(args.get("query") or "").strip()
                        yield _sse("status", {"state": "searching", "query": query})
                        try:
                            results = await self.searx.search(query)
                            formatted = self.searx.format_results(results)
                            search_meta.append({"query": query, "results": results})
                            tool_meta.append({"tool": "web_search", "query": query})
                            yield _sse("search", {"query": query, "results": results})
                        except Exception as exc:  # noqa: BLE001
                            formatted = f"Search failed: {exc}"
                            yield _sse("search", {"query": query, "error": str(exc)})

                        ollama_messages.append(
                            {"role": "tool", "content": formatted, "name": "web_search"}
                        )

                    elif name == "generate_image" and image_on:
                        prompt_img = str(args.get("prompt") or "").strip()
                        neg = str(args.get("negative_prompt") or "")
                        yield _sse("status", {"state": "drawing", "prompt": prompt_img})
                        try:
                            out_path = await self.comfy.generate(
                                prompt_img,
                                negative_prompt=neg,
                                save_dir=self.settings.media_path / chat_id,
                            )
                            rel = str(out_path.relative_to(self.settings.media_path)).replace("\\", "/")
                            url = f"/media/{rel}"
                            assistant_images.append(url)
                            tool_meta.append({"tool": "generate_image", "prompt": prompt_img, "url": url})
                            yield _sse("image", {"url": url, "prompt": prompt_img})
                            tool_result = (
                                f"Image generated successfully. URL for the client: {url}. "
                                f"Prompt used: {prompt_img}. Tell the user the image is ready; "
                                "do not invent a different description of pixels."
                            )
                        except Exception as exc:  # noqa: BLE001
                            tool_result = f"Image generation failed: {exc}"
                            yield _sse("status", {"state": "drawing_failed", "error": str(exc)})

                        ollama_messages.append(
                            {"role": "tool", "content": tool_result, "name": "generate_image"}
                        )

                    else:
                        ollama_messages.append(
                            {
                                "role": "tool",
                                "content": f"Tool unavailable or unknown: {name}",
                                "name": name or "unknown",
                            }
                        )

                content_acc = ""

            meta: dict[str, Any] = {}
            if search_meta:
                meta["searches"] = search_meta
            if tool_meta:
                meta["tools"] = tool_meta
            if assistant_images:
                meta["images"] = assistant_images

            # Persist assistant text + any generated images on the same message
            await self.db.update_message_content(
                assistant_msg["id"],
                full_text,
                meta=meta or None,
            )
            if assistant_images:
                # store images on message row
                await self.db.conn.execute(
                    "UPDATE messages SET images_json = ? WHERE id = ?",
                    (json.dumps(assistant_images), assistant_msg["id"]),
                )
                await self.db.conn.commit()

            yield _sse(
                "done",
                {
                    "id": assistant_msg["id"],
                    "content": full_text,
                    "images": assistant_images or None,
                    "meta": meta or None,
                    "model": use_model,
                },
            )
        except Exception as exc:  # noqa: BLE001
            err = str(exc)
            if full_text:
                await self.db.update_message_content(
                    assistant_msg["id"],
                    full_text + f"\n\n[Error: {err}]",
                )
            else:
                await self.db.update_message_content(assistant_msg["id"], f"[Error: {err}]")
            yield _sse("error", {"message": err})
