from fastapi import APIRouter, Depends, HTTPException

from ..auth import require_token
from ..config import Settings, get_settings
from ..db import db
from ..schemas import ImageGenerateRequest, MessageOut
from ..services.comfyui import ComfyUIClient

router = APIRouter(prefix="/images", tags=["images"])


@router.post("/generate", response_model=MessageOut, dependencies=[Depends(require_token)])
async def generate_image(
    body: ImageGenerateRequest,
    settings: Settings = Depends(get_settings),
) -> MessageOut:
    chat_id = body.chat_id
    if not chat_id:
        chat = await db.create_chat(title=body.prompt[:60] or "Image", model=settings.default_model)
        chat_id = chat["id"]
    else:
        chat = await db.get_chat(chat_id)
        if not chat:
            raise HTTPException(status_code=404, detail="Chat not found")

    await db.add_message(chat_id, "user", f"Generate image: {body.prompt}")

    client = ComfyUIClient(settings)
    try:
        out_path = await client.generate(
            body.prompt,
            negative_prompt=body.negative_prompt,
            width=body.width,
            height=body.height,
            steps=body.steps,
            seed=body.seed,
            save_dir=settings.media_path / chat_id,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Image generation failed: {exc}") from exc

    rel = str(out_path.relative_to(settings.media_path)).replace("\\", "/")
    url = f"/media/{rel}"
    msg = await db.add_message(
        chat_id,
        "assistant",
        f"Generated image for: {body.prompt}",
        images=[url],
        meta={"prompt": body.prompt, "type": "image_generation"},
    )
    return MessageOut(**msg)
