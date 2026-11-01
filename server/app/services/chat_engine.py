import base64
import json
from pathlib import Path
from typing import Any, AsyncIterator

from ..config import Settings
from ..db import Database
from .ollama import OllamaClient
from .searxng import SearxngClient

WEB_SEARCH_TOOL = {
    "type": "function",
    "function": {
        "name": "web_search",
        "description": "Search the web for up-to-date information. Use for news, facts, prices, and anything after your knowledge cutoff.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query",
                }
            },
            "required": ["query"],
        },
    },
}


def _sse(event: str, data: dict[str, Any]) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


class ChatEngine:
    def __init__(self, settings: Settings, db: Database) -> None:
        self.settings = settings
        self.db = db
        self.ollama = OllamaClient(settings)
        self.searx = SearxngClient(settings)

    def _history_to_ollama(self, messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        for m in messages:
            item: dict[str, Any] = {"role": m["role"], "content": m.get("content") or ""}
            images = m.get("images")
            if images:
                # Prefer base64 payloads already stored as data URLs or raw b64
                b64_list = []
                for img in images:
                    if isinstance(img, str) and img.startswith("data:"):
                        b64_list.append(img.split(",", 1)[-1])
                    elif isinstance(img, str) and Path(img).exists():
                        b64_list.append(base64.b64encode(Path(img).read_bytes()).decode("ascii"))
                    else:
                        b64_list.append(img)
                item["images"] = b64_list
            out.append(item)
        return out

    async def stream_reply(
        self,
        chat_id: str,
        user_text: str,
        *,
        model: str | None = None,
        enable_search: bool | None = None,
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
        prompt = system_prompt or self.settings.system_prompt

        # Persist user message
        stored_images: list[str] | None = None
        if image_paths:
            stored_images = image_paths
        elif image_b64:
            stored_images = image_b64

        user_msg = await self.db.add_message(
            chat_id,
            "user",
            user_text,
            images=stored_images,
        )
        yield _sse("user_message", user_msg)

        # Auto-title from first user message
        if chat["title"] in ("New chat", "", None):
            title = user_text.strip().split("\n", 1)[0][:60] or "New chat"
            await self.db.update_chat(chat_id, title=title, model=use_model)
            yield _sse("chat_updated", {"id": chat_id, "title": title, "model": use_model})
        else:
            await self.db.update_chat(chat_id, model=use_model)

        history = await self.db.list_messages(chat_id)
        ollama_messages: list[dict[str, Any]] = [{"role": "system", "content": prompt}]
        ollama_messages.extend(self._history_to_ollama(history))

        # If b64 provided separately for this turn and not in history images yet
        if image_b64 and ollama_messages:
            last = ollama_messages[-1]
            if last.get("role") == "user" and not last.get("images"):
                last["images"] = image_b64

        tools = [WEB_SEARCH_TOOL] if search_on else None
        assistant_msg = await self.db.add_message(chat_id, "assistant", "")
        yield _sse("assistant_start", {"id": assistant_msg["id"]})

        full_text = ""
        search_meta: list[dict[str, Any]] = []
        max_tool_rounds = 3

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

                    # Ollama may stream tool_calls
                    if msg.get("tool_calls"):
                        tool_calls_acc = msg["tool_calls"]

                    if chunk.get("done"):
                        # Final message may contain tool_calls
                        final_msg = chunk.get("message") or msg
                        if final_msg.get("tool_calls"):
                            tool_calls_acc = final_msg["tool_calls"]

                if not tool_calls_acc or not search_on:
                    break

                # Execute tools
                ollama_messages.append(
                    {
                        "role": "assistant",
                        "content": content_acc,
                        "tool_calls": tool_calls_acc,
                    }
                )
                for call in tool_calls_acc:
                    fn = call.get("function") or {}
                    name = fn.get("name")
                    raw_args = fn.get("arguments") or {}
                    if isinstance(raw_args, str):
                        try:
                            args = json.loads(raw_args)
                        except json.JSONDecodeError:
                            args = {"query": raw_args}
                    else:
                        args = raw_args

                    if name == "web_search":
                        query = str(args.get("query") or "").strip()
                        yield _sse("status", {"state": "searching", "query": query})
                        try:
                            results = await self.searx.search(query)
                            formatted = self.searx.format_results(results)
                            search_meta.append({"query": query, "results": results})
                            yield _sse("search", {"query": query, "results": results})
                        except Exception as exc:  # noqa: BLE001
                            formatted = f"Search failed: {exc}"
                            yield _sse("search", {"query": query, "error": str(exc)})

                        ollama_messages.append(
                            {
                                "role": "tool",
                                "content": formatted,
                                # Some Ollama builds expect name
                                "name": "web_search",
                            }
                        )
                    else:
                        ollama_messages.append(
                            {
                                "role": "tool",
                                "content": f"Unknown tool: {name}",
                                "name": name or "unknown",
                            }
                        )

                # Reset content accumulator for final answer after tools; keep full_text growing
                # Prefer replacing interim tool chatter with final answer — keep streamed tokens
                content_acc = ""

            meta = {"searches": search_meta} if search_meta else None
            await self.db.update_message_content(assistant_msg["id"], full_text, meta=meta)
            yield _sse(
                "done",
                {
                    "id": assistant_msg["id"],
                    "content": full_text,
                    "meta": meta,
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
