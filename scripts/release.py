"""Build and verify launcher assets without shell text encoding conversions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

TEXT = {".hx", ".md", ".json", ".ps1", ".py", ".yml", ".yaml", ".txt"}

def check_text(raw, name):
    text = raw.decode("utf-8")
    if not text.isascii():
        raise ValueError(f"{name}: non-ASCII text requires review; release blocked")
    if any(ord(c) < 32 and c not in "\r\n\t" for c in text):
        raise ValueError(f"{name}: unexpected control character")
    if name.endswith(".json"):
        check_strings(json.loads(text), name)
    return text

def check_strings(value, name):
    if isinstance(value, str) and not value.isascii():
        raise ValueError(f"{name}: escaped non-ASCII JSON string requires review")
    if isinstance(value, dict):
        for key, child in value.items():
            check_strings(key, name)
            check_strings(child, name)
    if isinstance(value, list):
        for child in value:
            check_strings(child, name)

def audit(root):
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=root).decode("utf-8").splitlines()
    for name in names:
        if Path(name).suffix.lower() in TEXT or Path(name).name == "LICENSE":
            check_text((root / name).read_bytes(), name)
    return names

def build(root, output):
    audit(root)
    manifest = json.loads((root / "mod.json").read_bytes())
    identifier, version = manifest["id"], manifest["version"]
    files = [root / n for n in ("mod.json", "README.md", "LICENSE")]
    for folder in ("src", "Resources"):
        files += [p for p in (root / folder).rglob("*") if p.is_file()]
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{identifier}-{version}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(files):
            z.writestr(path.relative_to(root).as_posix(), path.read_bytes())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for name in z.namelist():
            assert z.read(name) == (root / name).read_bytes(), name
            if Path(name).suffix in TEXT or Path(name).name == "LICENSE":
                check_text(z.read(name), name)
    readme = (root / "README.md").read_text(encoding="utf-8")
    shown = readme.split("<!-- drh:show -->", 1)[1].split("<!-- /drh:show -->", 1)[0].strip()
    repository = "https://github.com/Drandoxy/DRH-Mod-Auto-Dungeon-Loot-Manager"
    entry = {key: manifest[key] for key in ("id", "name", "version", "author", "description", "api", "drh", "uses")}
    entry.update(longDescription=shown, url=f"{repository}/releases/download/v{version}/{archive.name}", size=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), source=repository)
    index = output / f"{identifier}-{version}.json"
    index.write_bytes((json.dumps(entry, indent=2, ensure_ascii=True) + "\n").encode("utf-8"))
    check_text(index.read_bytes(), index.name)
    assert json.loads(index.read_bytes())["longDescription"] == shown
    print(json.dumps({"zip": str(archive), "json": str(index), "sha256": entry["sha256"], "files": len(files)}))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()
    build(Path(__file__).resolve().parents[1], args.output.resolve())
