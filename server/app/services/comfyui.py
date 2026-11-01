import asyncio
import random
import uuid
from pathlib import Path
from typing import Any

import httpx

from ..config import Settings

# Minimal SD1.5-compatible txt2img graph. User can replace checkpoint name via env later.
DEFAULT_WORKFLOW = {
    "3": {
        "class_type": "KSampler",
        "inputs": {
            "seed": 0,
            "steps": 20,
            "cfg": 7,
            "sampler_name": "euler",
            "scheduler": "normal",
            "denoise": 1,
            "model": ["4", 0],
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["5", 0],
        },
    },
    "4": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"},
    },
    "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": 1024, "height": 1024, "batch_size": 1},
    },
    "6": {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": "prompt", "clip": ["4", 1]},
    },
    "7": {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": "", "clip": ["4", 1]},
    },
    "8": {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["3", 0], "vae": ["4", 2]},
    },
    "9": {
        "class_type": "SaveImage",
        "inputs": {"filename_prefix": "valera_bot", "images": ["8", 0]},
    },
}


class ComfyUIClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.base = settings.comfy_url.rstrip("/")

    def _build_workflow(
        self,
        prompt: str,
        *,
        negative_prompt: str = "",
        width: int = 1024,
        height: int = 1024,
        steps: int = 20,
        seed: int | None = None,
    ) -> dict[str, Any]:
        import copy

        wf = copy.deepcopy(DEFAULT_WORKFLOW)
        wf["6"]["inputs"]["text"] = prompt
        wf["7"]["inputs"]["text"] = negative_prompt
        wf["5"]["inputs"]["width"] = width
        wf["5"]["inputs"]["height"] = height
        wf["3"]["inputs"]["steps"] = steps
        wf["3"]["inputs"]["seed"] = seed if seed is not None else random.randint(0, 2**32 - 1)
        return wf

    async def generate(
        self,
        prompt: str,
        *,
        negative_prompt: str = "",
        width: int = 1024,
        height: int = 1024,
        steps: int = 20,
        seed: int | None = None,
        save_dir: Path,
    ) -> Path:
        workflow = self._build_workflow(
            prompt,
            negative_prompt=negative_prompt,
            width=width,
            height=height,
            steps=steps,
            seed=seed,
        )
        client_id = str(uuid.uuid4())
        async with httpx.AsyncClient(timeout=600.0) as client:
            resp = await client.post(
                f"{self.base}/prompt",
                json={"prompt": workflow, "client_id": client_id},
            )
            resp.raise_for_status()
            prompt_id = resp.json()["prompt_id"]

            # Poll history until done
            image_meta = None
            for _ in range(300):
                hist = await client.get(f"{self.base}/history/{prompt_id}")
                hist.raise_for_status()
                data = hist.json()
                if prompt_id in data:
                    outputs = data[prompt_id].get("outputs", {})
                    for node_out in outputs.values():
                        images = node_out.get("images") or []
                        if images:
                            image_meta = images[0]
                            break
                    if image_meta:
                        break
                await asyncio.sleep(1.0)

            if not image_meta:
                raise TimeoutError("ComfyUI generation timed out")

            params = {
                "filename": image_meta["filename"],
                "subfolder": image_meta.get("subfolder", ""),
                "type": image_meta.get("type", "output"),
            }
            img_resp = await client.get(f"{self.base}/view", params=params)
            img_resp.raise_for_status()

        save_dir.mkdir(parents=True, exist_ok=True)
        out_path = save_dir / f"{uuid.uuid4().hex}.png"
        out_path.write_bytes(img_resp.content)
        return out_path
