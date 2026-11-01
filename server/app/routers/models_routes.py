from fastapi import APIRouter, Depends, HTTPException

from ..auth import require_token
from ..config import Settings, get_settings
from ..schemas import ModelOut
from ..services.ollama import OllamaClient

router = APIRouter(prefix="/models", tags=["models"])


@router.get("", response_model=list[ModelOut], dependencies=[Depends(require_token)])
async def list_models(settings: Settings = Depends(get_settings)) -> list[ModelOut]:
    client = OllamaClient(settings)
    try:
        models = await client.list_models()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Ollama unreachable: {exc}") from exc
    return [ModelOut(**m) for m in models]
