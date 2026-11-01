from typing import Any

from pydantic import BaseModel, Field


class TokenCheckResponse(BaseModel):
    ok: bool = True


class ChatCreate(BaseModel):
    title: str = "New chat"
    model: str | None = None


class ChatUpdate(BaseModel):
    title: str | None = None
    model: str | None = None


class ChatOut(BaseModel):
    id: str
    title: str
    model: str | None = None
    created_at: str
    updated_at: str


class MessageOut(BaseModel):
    id: str
    chat_id: str
    role: str
    content: str
    images: list[str] | None = None
    meta: dict[str, Any] | None = None
    created_at: str


class SendMessageRequest(BaseModel):
    content: str = Field(min_length=1)
    model: str | None = None
    enable_search: bool | None = None
    system_prompt: str | None = None


class ImageGenerateRequest(BaseModel):
    prompt: str = Field(min_length=1)
    chat_id: str | None = None
    negative_prompt: str = ""
    width: int = 1024
    height: int = 1024
    steps: int = 20
    seed: int | None = None


class ModelOut(BaseModel):
    name: str
    size: int | None = None
    modified_at: str | None = None


class SettingsOut(BaseModel):
    default_model: str
    vision_model: str
    enable_search: bool
    system_prompt: str
