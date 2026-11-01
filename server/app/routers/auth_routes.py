from fastapi import APIRouter, Depends

from ..auth import require_token
from ..config import Settings, get_settings
from ..schemas import SettingsOut, TokenCheckResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/token", response_model=TokenCheckResponse, dependencies=[Depends(require_token)])
async def check_token() -> TokenCheckResponse:
    return TokenCheckResponse(ok=True)


@router.get("/settings", response_model=SettingsOut, dependencies=[Depends(require_token)])
async def get_public_settings(settings: Settings = Depends(get_settings)) -> SettingsOut:
    return SettingsOut(
        default_model=settings.default_model,
        vision_model=settings.vision_model,
        enable_search=settings.enable_search,
        system_prompt=settings.system_prompt,
    )
