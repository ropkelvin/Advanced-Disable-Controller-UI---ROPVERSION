from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
addon = root / "ESOHybridUI"
manifest = addon / "ESOHybridUI.txt"

if not manifest.is_file():
    raise SystemExit("Missing ESOHybridUI/ESOHybridUI.txt")

entries = []
for raw in manifest.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("##"):
        continue
    path = Path(line.replace("/", "/"))
    if path.is_absolute() or ".." in path.parts:
        raise SystemExit(f"Unsafe manifest path: {line}")
    target = addon.joinpath(*path.parts)
    if not target.is_file():
        raise SystemExit(f"Manifest references missing file: {line}")
    entries.append(line)

if not entries:
    raise SystemExit("Manifest contains no loadable files")

print(f"Manifest OK: {len(entries)} loadable files")
