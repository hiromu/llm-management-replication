"""Local article PDFs, explicitly paired figures and saved page crops."""
from __future__ import annotations

import base64
import hashlib
import json
import math
from pathlib import Path
import re
import uuid

PLACEHOLDER = Path(__file__).resolve().parents[1] / "static/paper-placeholder.pdf"


def placeholder_asset(url: str, aid: str = "article") -> dict:
    return {"id": aid, "name": PLACEHOLDER.name, "kind": "pdf", "url": url,
            "sha256": hashlib.sha256(PLACEHOLDER.read_bytes()).hexdigest(), "placeholder": True}


def directory(runtime: Path, study: str) -> Path:
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,63}", study):
        raise ValueError("Invalid study ID")
    return runtime / "media" / study


def manifest(runtime: Path, study: str) -> dict:
    path = directory(runtime, study) / "manifest.json"
    if path.exists():
        return json.loads(path.read_text())
    return {"article": None, "assets": {}, "pairs": [{"id": "figure1", "label": "Figure 1", "original": None, "rebuilt": None, "views": {}}]}


def save(runtime: Path, study: str, value: dict) -> None:
    root = directory(runtime, study)
    root.mkdir(parents=True, exist_ok=True)
    tmp = root / "manifest.tmp"
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(root / "manifest.json")


def state(runtime: Path, study: str) -> dict:
    data = manifest(runtime, study)
    def asset(aid: str | None) -> dict | None:
        if not aid:
            return None
        if aid == "article":
            return placeholder_asset(f"/api/studies/{study}/media/article/archive")
        a = data["assets"].get(aid)
        if a is None or not (directory(runtime, study) / a["file"]).is_file():
            return None
        return {**a, "url": f"/api/studies/{study}/media/asset/{aid}"}
    article = asset(data["article"])
    if not article:
        article = asset("article")
    result = {"article": article, "article_view": data.get("article_view", {}), "pairs": []}
    for p in data["pairs"]:
        result["pairs"].append({**p, "original": asset(p["original"]), "rebuilt": asset(p["rebuilt"])})
    return result


def crop_view(value: dict) -> dict:
    page = value.get("page", 1)
    if isinstance(page, bool) or not isinstance(page, int) or not 1 <= page <= 10000:
        raise ValueError("Invalid PDF page")
    crop = value.get("crop", {"x": 0, "y": 0, "w": 1, "h": 1})
    if not isinstance(crop, dict) or not all(isinstance(crop.get(k), (int, float)) and math.isfinite(crop[k]) for k in ("x", "y", "w", "h")):
        raise ValueError("Invalid crop")
    x, y, w, h = (crop[k] for k in ("x", "y", "w", "h"))
    if min(x, y) < 0 or min(w, h) <= .001 or x+w > 1.00001 or y+h > 1.00001:
        raise ValueError("Crop must be inside the page")
    return {"page": page, "crop": dict(crop)}


def update(runtime: Path, study: str, body: dict) -> dict:
    data = manifest(runtime, study)
    # Preserve references created by earlier workbench versions before replacing an article.
    if data["article"]:
        for p in data["pairs"]:
            if not p["original"]:
                p["original"] = data["article"]
    action = body.get("action", "upload")
    if action == "pair":
        pid = uuid.uuid4().hex[:12]
        reference = data["article"] or "article"
        data["pairs"].append({"id": pid, "label": str(body.get("label") or f"Figure {len(data['pairs'])+1}")[:80], "original": reference, "rebuilt": None, "views": {}})
    elif action == "axes":
        pair = next((p for p in data["pairs"] if p["id"] == body.get("pair_id", "figure1")), None)
        if not pair:
            raise ValueError("Unknown figure pair")
        axes = body.get("axes")
        if axes is not None:
            if not isinstance(axes, dict):
                raise ValueError("Supply both figures' linear axis ranges")
            for side in ["original", "rebuilt"]:
                a = axes.get(side, {})
                if not all(isinstance(a.get(k), (int, float)) and not isinstance(a[k], bool) and math.isfinite(a[k]) for k in ["xmin", "xmax", "ymin", "ymax"]):
                    raise ValueError("Supply both figures' linear axis ranges")
                if a["xmin"] >= a["xmax"] or a["ymin"] >= a["ymax"] or not math.isfinite(a["xmax"]-a["xmin"]) or not math.isfinite(a["ymax"]-a["ymin"]):
                    raise ValueError("Axis minimum must be smaller than maximum")
        pair["axes"] = axes
    else:
        slot = body.get("slot")
        if slot not in ["article", "original", "rebuilt"]:
            raise ValueError("Invalid media slot")
        pair = next((p for p in data["pairs"] if p["id"] == body.get("pair_id", "figure1")), None)
        if slot != "article" and pair is None:
            raise ValueError("Unknown figure pair")
        if action == "view":
            if slot == "article":
                data["article_view"] = crop_view(body.get("view", {}))
            else:
                view = crop_view(body.get("view", {}))
                if slot == "original" and not pair["original"]:
                    pair["original"] = data["article"] or "article"
                if pair["views"].get(slot, {}).get("page", 1) != view["page"]:
                    pair["axes"] = None
                pair["views"][slot] = view
        elif action == "upload":
            try:
                binary = base64.b64decode(body.get("base64", ""), validate=True)
            except Exception:
                raise ValueError("Invalid media upload")
            if len(binary) > 30 * 1024 * 1024:
                raise ValueError("Maximum file size is 30 MB")
            if binary.startswith(b"%PDF-"):
                suffix, kind, mime = ".pdf", "pdf", "application/pdf"
            elif binary.startswith(b"\x89PNG\r\n\x1a\n"):
                suffix, kind, mime = ".png", "image", "image/png"
            elif binary.startswith(b"\xff\xd8\xff"):
                suffix, kind, mime = ".jpg", "image", "image/jpeg"
            elif binary.startswith(b"RIFF") and binary[8:12] == b"WEBP":
                suffix, kind, mime = ".webp", "image", "image/webp"
            else:
                raise ValueError("Use a PDF, PNG, JPEG or WebP file")
            if slot in ["article", "original"] and kind != "pdf":
                raise ValueError("The original reference must come from a PDF")
            aid = uuid.uuid4().hex
            root = directory(runtime, study)
            root.mkdir(parents=True, exist_ok=True)
            (root / (aid + suffix)).write_bytes(binary)
            data["assets"][aid] = {"id": aid, "file": aid+suffix, "name": Path(str(body.get("name", "Upload"))).name[:150], "kind": kind, "mime": mime, "sha256": hashlib.sha256(binary).hexdigest(), "bytes": len(binary), "placeholder": binary == PLACEHOLDER.read_bytes()}
            if slot == "article":
                data["article"] = aid
                data["article_view"] = crop_view({})
                for p in data["pairs"]:
                    if not p["original"]:
                        p["original"] = aid
                        p["axes"] = None
                        p["views"]["original"] = crop_view({})
            else:
                pair[slot] = aid
                pair["views"][slot] = crop_view({})
                pair["axes"] = None
                if slot == "original" and data["article"] is None:
                    data["article"] = aid
        else:
            raise ValueError("Unknown media action")
    save(runtime, study, data)
    return state(runtime, study)


def resolve(runtime: Path, study: str, kind: str, aid: str = "") -> tuple[Path, str]:
    data = manifest(runtime, study)
    if kind == "article":
        if aid == "archive":
            return PLACEHOLDER, "application/pdf"
        uploaded = data["assets"].get(data["article"])
        if uploaded and (directory(runtime, study) / uploaded["file"]).is_file():
            aid = data["article"]
        else:
            return PLACEHOLDER, "application/pdf"
    if aid not in data["assets"]:
        raise ValueError("Unknown media asset")
    asset = data["assets"][aid]
    return directory(runtime, study) / asset["file"], asset["mime"]
