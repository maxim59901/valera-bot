import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

import aiosqlite

from .config import get_settings

SCHEMA = """
CREATE TABLE IF NOT EXISTS chats (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'New chat',
    model TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    images_json TEXT,
    meta_json TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_id() -> str:
    return uuid4().hex


class Database:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._conn: aiosqlite.Connection | None = None

    async def connect(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = await aiosqlite.connect(self.path)
        self._conn.row_factory = aiosqlite.Row
        await self._conn.executescript(SCHEMA)
        await self._conn.commit()

    async def close(self) -> None:
        if self._conn:
            await self._conn.close()
            self._conn = None

    @property
    def conn(self) -> aiosqlite.Connection:
        if not self._conn:
            raise RuntimeError("Database is not connected")
        return self._conn

    async def list_chats(self) -> list[dict[str, Any]]:
        cur = await self.conn.execute(
            "SELECT id, title, model, created_at, updated_at FROM chats ORDER BY updated_at DESC"
        )
        rows = await cur.fetchall()
        return [dict(r) for r in rows]

    async def create_chat(self, title: str = "New chat", model: str | None = None) -> dict[str, Any]:
        chat_id = _new_id()
        now = _now()
        await self.conn.execute(
            "INSERT INTO chats (id, title, model, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            (chat_id, title, model, now, now),
        )
        await self.conn.commit()
        return {
            "id": chat_id,
            "title": title,
            "model": model,
            "created_at": now,
            "updated_at": now,
        }

    async def get_chat(self, chat_id: str) -> dict[str, Any] | None:
        cur = await self.conn.execute(
            "SELECT id, title, model, created_at, updated_at FROM chats WHERE id = ?",
            (chat_id,),
        )
        row = await cur.fetchone()
        return dict(row) if row else None

    async def update_chat(
        self,
        chat_id: str,
        *,
        title: str | None = None,
        model: str | None = None,
        touch: bool = True,
    ) -> None:
        fields: list[str] = []
        values: list[Any] = []
        if title is not None:
            fields.append("title = ?")
            values.append(title)
        if model is not None:
            fields.append("model = ?")
            values.append(model)
        if touch:
            fields.append("updated_at = ?")
            values.append(_now())
        if not fields:
            return
        values.append(chat_id)
        await self.conn.execute(f"UPDATE chats SET {', '.join(fields)} WHERE id = ?", values)
        await self.conn.commit()

    async def delete_chat(self, chat_id: str) -> bool:
        cur = await self.conn.execute("DELETE FROM chats WHERE id = ?", (chat_id,))
        await self.conn.execute("DELETE FROM messages WHERE chat_id = ?", (chat_id,))
        await self.conn.commit()
        return cur.rowcount > 0

    async def list_messages(self, chat_id: str) -> list[dict[str, Any]]:
        cur = await self.conn.execute(
            """
            SELECT id, chat_id, role, content, images_json, meta_json, created_at
            FROM messages WHERE chat_id = ? ORDER BY created_at ASC
            """,
            (chat_id,),
        )
        rows = await cur.fetchall()
        result = []
        for row in rows:
            item = dict(row)
            item["images"] = json.loads(item.pop("images_json") or "null")
            item["meta"] = json.loads(item.pop("meta_json") or "null")
            result.append(item)
        return result

    async def add_message(
        self,
        chat_id: str,
        role: str,
        content: str,
        *,
        images: list[str] | None = None,
        meta: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        msg_id = _new_id()
        now = _now()
        await self.conn.execute(
            """
            INSERT INTO messages (id, chat_id, role, content, images_json, meta_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                msg_id,
                chat_id,
                role,
                content,
                json.dumps(images) if images else None,
                json.dumps(meta) if meta else None,
                now,
            ),
        )
        await self.conn.execute("UPDATE chats SET updated_at = ? WHERE id = ?", (now, chat_id))
        await self.conn.commit()
        return {
            "id": msg_id,
            "chat_id": chat_id,
            "role": role,
            "content": content,
            "images": images,
            "meta": meta,
            "created_at": now,
        }

    async def update_message_content(self, message_id: str, content: str, meta: dict[str, Any] | None = None) -> None:
        if meta is not None:
            await self.conn.execute(
                "UPDATE messages SET content = ?, meta_json = ? WHERE id = ?",
                (content, json.dumps(meta), message_id),
            )
        else:
            await self.conn.execute("UPDATE messages SET content = ? WHERE id = ?", (content, message_id))
        await self.conn.commit()


db = Database(get_settings().db_path)
