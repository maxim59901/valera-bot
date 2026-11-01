from typing import Any

import httpx

from ..config import Settings


class SearxngClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.base = settings.searxng_url.rstrip("/")

    async def search(self, query: str, *, limit: int = 8) -> list[dict[str, Any]]:
        params = {
            "q": query,
            "format": "json",
            "language": "auto",
        }
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(f"{self.base}/search", params=params)
            resp.raise_for_status()
            data = resp.json()
        results = []
        for item in data.get("results", [])[:limit]:
            results.append(
                {
                    "title": item.get("title") or "",
                    "url": item.get("url") or "",
                    "content": item.get("content") or item.get("snippet") or "",
                    "engine": item.get("engine"),
                }
            )
        return results

    def format_results(self, results: list[dict[str, Any]]) -> str:
        if not results:
            return "No web results found."
        lines = []
        for i, r in enumerate(results, 1):
            lines.append(f"{i}. {r['title']}\n   URL: {r['url']}\n   {r['content']}")
        return "\n\n".join(lines)
