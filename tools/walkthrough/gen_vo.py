#!/usr/bin/env python3
"""Generate walkthrough MP3s with edge-tts. Run from repo root or this folder."""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

VOICES = {
    "scav": "en-US-GuyNeural",
    "tam": "en-GB-RyanNeural",
}
TAM_FALLBACKS = [
    "en-GB-RyanNeural",
    "en-US-EricNeural",
    "en-US-GuyNeural",
]
RATES = {
    "scav": "-8%",
    "tam": "-8%",
}


def _root() -> Path:
    here = Path(__file__).resolve().parent
    return here.parent.parent


async def _one(edge_tts, out: Path, who: str, text: str, voice: str | None = None) -> None:
    chosen = voice or VOICES.get(who, VOICES["scav"])
    kwargs: dict = {"rate": RATES.get(who, "-8%")}
    if who == "scav":
        kwargs["pitch"] = "-2Hz"
    communicate = edge_tts.Communicate(text, chosen, **kwargs)
    await communicate.save(str(out))
    print("VO", out.name, who, chosen, "ok")


async def main() -> int:
	try:
		import edge_tts
	except ImportError:
		print("edge-tts missing. pip install edge-tts", file=sys.stderr)
		return 1
	folder = Path(__file__).resolve().parent
	lines_path = folder / "lines.json"
	out_dir = folder / "vo"
	out_dir.mkdir(parents=True, exist_ok=True)
	data = json.loads(lines_path.read_text(encoding="utf-8"))
	ok = 0
	for beat_id, spec in data.items():
		who = str(spec.get("who", "scav"))
		text = str(spec.get("text", "")).strip()
		if not text:
			continue
		dest = out_dir / f"{beat_id}.mp3"
		if dest.exists() and dest.stat().st_size > 1000:
			print("VO skip", dest.name)
			ok += 1
			continue
		last_err: Exception | None = None
		voices = TAM_FALLBACKS if who == "tam" else [VOICES["scav"]]
		for voice in voices:
			for attempt in range(3):
				try:
					await _one(edge_tts, dest, who, text, voice)
					ok += 1
					last_err = None
					break
				except Exception as err:  # noqa: BLE001
					last_err = err
					print("VO retry", beat_id, voice, attempt + 1, err)
					await asyncio.sleep(0.6 * float(attempt + 1))
			if last_err is None:
				break
		if last_err is not None:
			print("VO FAIL", beat_id, last_err, file=sys.stderr)
			return 1
		await asyncio.sleep(0.25)
	print("VO_DONE", ok, "files ->", out_dir)
	return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
