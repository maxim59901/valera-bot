import base64
import shutil
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from ..auth import require_token
from ..config import Settings, get_settings
from ..db import db
from ..schemas import ChatCreate, ChatOut, ChatUpdate, MessageOut, SendMessageRequest
from ..services.chat_engine import ChatEngine

router = APIRouter(prefix="/chats", tags=["chats"])


@router.get("", response_model=list[ChatOut], dependencies=[Depends(require_token)])
async def list_chats() -> list[ChatOut]:
    rows = await db.list_chats()
    return [ChatOut(**r) for r in rows]


@router.post("", response_model=ChatOut, dependencies=[Depends(require_token)])
async def create_chat(body: ChatCreate, settings: Settings = Depends(get_settings)) -> ChatOut:
    chat = await db.create_chat(title=body.title, model=body.model or settings.default_model)
    return ChatOut(**chat)


@router.get("/{chat_id}", response_model=ChatOut, dependencies=[Depends(require_token)])
async def get_chat(chat_id: str) -> ChatOut:
    chat = await db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    return ChatOut(**chat)


@router.patch("/{chat_id}", response_model=ChatOut, dependencies=[Depends(require_token)])
async def update_chat(chat_id: str, body: ChatUpdate) -> ChatOut:
    chat = await db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    await db.update_chat(chat_id, title=body.title, model=body.model)
    updated = await db.get_chat(chat_id)
    assert updated
    return ChatOut(**updated)


@router.delete("/{chat_id}", dependencies=[Depends(require_token)])
async def delete_chat(chat_id: str) -> dict[str, bool]:
    ok = await db.delete_chat(chat_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Chat not found")
    return {"ok": True}


@router.get("/{chat_id}/messages", response_model=list[MessageOut], dependencies=[Depends(require_token)])
async def list_messages(chat_id: str) -> list[MessageOut]:
    chat = await db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    rows = await db.list_messages(chat_id)
    return [MessageOut(**r) for r in rows]


@router.post("/{chat_id}/messages", dependencies=[Depends(require_token)])
async def send_message(
    chat_id: str,
    body: SendMessageRequest,
    settings: Settings = Depends(get_settings),
) -> StreamingResponse:
    chat = await db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    engine = ChatEngine(settings, db)

    async def event_gen():
        async for chunk in engine.stream_reply(
            chat_id,
            body.content,
            model=body.model,
            enable_search=body.enable_search,
            system_prompt=body.system_prompt,
        ):
            yield chunk

    return StreamingResponse(event_gen(), media_type="text/event-stream")


@router.post("/{chat_id}/vision", dependencies=[Depends(require_token)])
async def send_vision(
    chat_id: str,
    content: str = Form(...),
    model: str | None = Form(default=None),
    enable_search: str | None = Form(default=None),
    system_prompt: str | None = Form(default=None),
    files: list[UploadFile] = File(default=[]),
    settings: Settings = Depends(get_settings),
) -> StreamingResponse:
    chat = await db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    search_flag: bool | None = None
    if enable_search is not None:
        search_flag = enable_search.strip().lower() in ("1", "true", "yes", "on")

    media_dir = settings.media_path / chat_id
    media_dir.mkdir(parents=True, exist_ok=True)
    saved_paths: list[str] = []
    b64_list: list[str] = []

    for upload in files:
        suffix = Path(upload.filename or "image.png").suffix or ".png"
        dest = media_dir / f"{uuid4().hex}{suffix}"
        with dest.open("wb") as out:
            shutil.copyfileobj(upload.file, out)
        data = dest.read_bytes()
        b64_list.append(base64.b64encode(data).decode("ascii"))
        rel = str(dest.relative_to(settings.media_path)).replace("\\", "/")
        saved_paths.append(f"/media/{rel}")

    engine = ChatEngine(settings, db)

    async def event_gen():
        async for chunk in engine.stream_reply(
            chat_id,
            content,
            model=model or settings.vision_model,
            enable_search=search_flag,
            system_prompt=system_prompt,
            image_paths=saved_paths or None,
            image_b64=b64_list or None,
        ):
            yield chunk

    return StreamingResponse(event_gen(), media_type="text/event-stream")
