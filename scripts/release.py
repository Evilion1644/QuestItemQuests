"""Build checks and fail-closed, single-attempt CurseForge publication."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "QLens"
ADDONS = (ADDON, ADDON + "_Guide")
NUMBER = r"(?:0|[1-9][0-9]*)"
SEMVER = rf"{NUMBER}\.{NUMBER}\.{NUMBER}(?:-(?:alpha|beta)\.{NUMBER})?"
CF = "https://wow.curseforge.com/api"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def config():
    return json.loads((ROOT / "release-config.json").read_text(encoding="utf-8"))


def toc(data):
    metadata, files = {}, []
    for line in data.decode("utf-8-sig").splitlines():
        line = line.strip()
        if line.startswith("##"):
            key, sep, value = line[2:].partition(":")
            if sep:
                require(key.strip() not in metadata, "Duplicate TOC metadata")
                metadata[key.strip()] = value.strip()
        elif line and not line.startswith("#"):
            path = PurePosixPath(line.replace("\\", "/"))
            require(not path.is_absolute() and ".." not in path.parts and ":" not in str(path), "Unsafe TOC path")
            require(path.suffix.lower() == ".lua", "New non-Lua TOC entry needs recursive validation support")
            files.append(str(path))
    require(files and len(files) == len(set(files)), "Empty or duplicate TOC entries")
    require(metadata.get("Interface") == config()["interface"], "Expected only Interface 16001")
    require(not any(k.startswith("Interface-") for k in metadata), "Unexpected extra game flavor")
    require(re.fullmatch(SEMVER, metadata.get("Version", "")), "TOC Version must be X.Y.Z or X.Y.Z-alpha.N / X.Y.Z-beta.N")
    return metadata, files


def release_tag(version):
    if os.environ.get("GITHUB_REF_TYPE") == "tag":
        tag = os.environ.get("GITHUB_REF_NAME", "")
        require(re.fullmatch("v" + SEMVER, tag), "Invalid release tag (expected vX.Y.Z or vX.Y.Z-alpha.N / vX.Y.Z-beta.N)")
        require(tag == "v" + version, "Tag and TOC Version differ")
        require(git("rev-parse", f"{tag}^{{commit}}") == git("rev-parse", "HEAD"), "Tag does not point to checkout")
        subprocess.run(["git", "merge-base", "--is-ancestor", "HEAD", "origin/main"], cwd=ROOT, check=True)
        return tag
    return None


def lua_check(data, name):
    compiler = shutil.which("luac5.1") or shutil.which("luac")
    if compiler:
        result = subprocess.run([compiler, "-p", "-"], input=data, capture_output=True)
        require(result.returncode == 0, f"Lua syntax error in {name}: {result.stderr.decode(errors='replace')}")
    else:
        # Local Windows verification, also compiling with Lua 5.1 without executing.
        from lupa.lua51 import LuaRuntime
        runtime = LuaRuntime(encoding=None)
        result = runtime.eval(b"function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")(data, name.encode())
        require(result[0], f"Lua syntax error in {name}: {result[1]}")


def sources():
    metadata_by_addon, all_files = {}, set()
    for addon in ADDONS:
        folder = ROOT / addon
        metadata, files = toc((folder / (addon + ".toc")).read_bytes())
        metadata_by_addon[addon] = metadata
        actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
        for name in files:
            require(name in actual, f"TOC file missing (case sensitive): {addon}/{name}")
        for name in sorted(actual):
            if name.endswith(".lua"):
                lua_check((folder / name).read_bytes(), f"{addon}/{name}")
        all_files.update(f"{addon}/{name}" for name in actual)
    main = metadata_by_addon[ADDON]
    guide = metadata_by_addon[ADDON + "_Guide"]
    require(guide["Version"] == main["Version"], "Core and Guide versions differ")
    require(guide.get("Dependencies") == ADDON and guide.get("LoadOnDemand") == "1", "Invalid Guide dependency/loading metadata")
    release_tag(main["Version"])
    return main, all_files


def release_type(version):
    require(re.fullmatch(SEMVER, version), "Invalid release version")
    return version.split("-", 1)[1].split(".", 1)[0] if "-" in version else "release"


def prepare():
    metadata, _ = sources()
    tags = git("tag", "--merged", "HEAD", "--sort=-version:refname").splitlines()
    previous = next((t for t in tags if re.fullmatch("v" + SEMVER, t) and git("rev-parse", f"{t}^{{commit}}") != git("rev-parse", "HEAD")), None)
    revision_range = f"{previous}..HEAD" if previous else "HEAD"
    changes = git("log", "--format=%h", revision_range).splitlines()
    paths = git("diff", "--name-only", previous, "HEAD").splitlines() if previous else git("ls-files").splitlines()
    # English templates avoid copying untranslated commit subjects into release notes.
    lines = [f"# QLens {metadata['Version']}", "", "Target: World of Warcraft: Forever 1.60.1 (Interface 16001).", "", "## Changes", ""]
    categories = [
        (lambda p: p.endswith("QuestItemQuestsData.lua"), "Updated the quest and item reference data."),
        (lambda p: p.endswith("QuestItemQuests.lua"), "Updated the addon implementation."),
        (lambda p: p.startswith("QLens_Guide/"), "Updated the offline quest guide and reward reference data."),
        (lambda p: p.endswith(("Locale.lua", "Titles.lua")), "Updated Russian and English localization."),
        (lambda p: p.endswith(".toc"), "Updated addon metadata."),
        (lambda p: p.endswith(".md"), "Updated documentation."),
        (lambda p: p.startswith(("scripts/", "tests/", ".github/")) or p in (".pkgmeta", "release-config.json"), "Updated build and release automation."),
    ]
    for predicate, text in categories:
        if any(predicate(p) for p in paths):
            lines.append("- " + text)
    lines += ["", "## Included commits", ""] + [f"- Commit `{sha}`." for sha in changes]
    if previous:
        lines += ["", f"[Full comparison](https://github.com/Evilion1644/QuestItemQuests/compare/{previous}...{git('rev-parse', 'HEAD')})"]
    (ROOT / ".build").mkdir(exist_ok=True)
    (ROOT / ".build/CHANGELOG.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Sources valid: version {metadata['Version']}; English changelog generated")


def verify():
    metadata, source_files = sources()
    archives = list((ROOT / ".release").glob("*.zip"))
    require(len(archives) == 1, "Expected exactly one release ZIP")
    archive = archives[0]
    with zipfile.ZipFile(archive) as package:
        require(package.testzip() is None, "ZIP CRC failed")
        names = package.namelist()
        require(len(names) == len(set(names)), "Duplicate ZIP entries")
        for name in names:
            path = PurePosixPath(name)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in name, "Unsafe ZIP path")
            require(path.parts[0] in ADDONS, f"Unexpected ZIP root: {name}")
            require(len(path.parts) < 2 or path.parts[1] not in ADDONS, "Double-nested addon")
        files = {name for name in names if not name.endswith("/")}
        expected = source_files
        # Packager can copy the generated changelog into the package root.
        extras = files - expected
        require(all(PurePosixPath(p).parent == PurePosixPath(ADDON) and PurePosixPath(p).name.startswith("CHANGELOG") for p in extras), f"Unexpected packaged files: {extras}")
        require(expected <= files, "ZIP is missing source files")
        for addon in ADDONS:
            toc_path = f"{addon}/{addon}.toc"
            packed_metadata, listed = toc(package.read(toc_path))
            source_metadata, _ = toc((ROOT / toc_path).read_bytes())
            require(packed_metadata == source_metadata, "Packaged TOC metadata differs")
            require(all(f"{addon}/{name}" in files for name in listed), "ZIP TOC references missing files")
        for name in source_files:
            packed = package.read(name)
            original = (ROOT / name).read_bytes()
            require(packed.replace(b"\r\n", b"\n") == original.replace(b"\r\n", b"\n"), f"Unexpected content change: {name}")
            if name.endswith(".lua"):
                lua_check(packed, name)
    print(f"ZIP valid: {archive.name}; SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}")
    return archive, metadata


def request_json(url, token, payload=None, github=False):
    headers = {"User-Agent": "QuestItemQuests-release", "Accept": "application/json"}
    headers["Authorization" if github else "X-Api-Token"] = "Bearer " + token if github else token
    body = None if payload is None else json.dumps(payload).encode()
    if body:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def forever_version(rows):
    cfg = config()
    matches = [row for row in rows if row.get("name") == cfg["game_version"] and row.get("gameVersionTypeID") == cfg["game_version_type_id"]]
    require(len(matches) == 1 and type(matches[0].get("id")) is int and matches[0]["id"] > 0,
            "No unique CurseForge Forever 1.60.1 ID; publication stopped (no fallback)")
    return matches[0]["id"]


def publish():
    require(os.environ.get("GITHUB_EVENT_NAME") == "push" and os.environ.get("GITHUB_REF_TYPE") == "tag", "Publication requires a tag push")
    archive, metadata = verify()
    tag = release_tag(metadata["Version"])
    cfg = config()
    project = cfg["curseforge_project_id"]
    require(type(project) is int and project > 0, "Set the existing CurseForge Project ID in release-config.json")
    require(metadata["Version"] not in cfg["previously_published_versions"], "Version already published before this workflow")
    token = os.environ.get("CF_API_TOKEN", "")
    gh_token = os.environ.get("GH_TOKEN", "")
    require(token and gh_token, "Required repository secret/token missing")
    game_id = forever_version(request_json(CF + "/game/wow/versions", token))
    changelog = (ROOT / ".build/CHANGELOG.md").read_text(encoding="utf-8")
    require(changelog.startswith(f"# QLens {metadata['Version']}\n"), "Changelog version mismatch")
    payload = {"displayName": tag + "-forever", "gameVersions": [game_id], "releaseType": release_type(metadata["Version"]), "changelogType": "markdown", "changelog": changelog}
    boundary = "----qiq" + uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n'.encode()
            + json.dumps(payload).encode()
            + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode()
            + archive.read_bytes() + f'\r\n--{boundary}--\r\n'.encode())
    # Atomic, persistent claim BEFORE the non-idempotent upload. Never delete on failure.
    repo = os.environ["GITHUB_REPOSITORY"]
    require(repo == "Evilion1644/QuestItemQuests", "Unexpected publication repository")
    request_json(f"https://api.github.com/repos/{repo}/git/refs", gh_token,
                 {"ref": f"refs/heads/curseforge-releases/{tag}", "sha": git("rev-parse", "HEAD")}, github=True)
    print(f"Claimed {tag}; uploading once for Forever game version ID {game_id}", flush=True)
    request = urllib.request.Request(f"{CF}/projects/{project}/upload-file", data=body,
                                     headers={"X-Api-Token": token, "Content-Type": "multipart/form-data; boundary=" + boundary})
    # No retries: a lost response must not cause a second upload.
    with urllib.request.urlopen(request, timeout=120) as response:
        result = json.load(response)
    require(type(result.get("id")) is int and result["id"] > 0, "Upload response has no file ID; inspect CurseForge before recovery")
    print(f"CurseForge file ID: {result['id']}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(f"Published {tag} to CurseForge project {project}, file {result['id']}, Forever 1.60.1 (ID {game_id}).\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "verify", "publish"])
    args = parser.parse_args()
    try:
        {"prepare": prepare, "verify": verify, "publish": publish}[args.command]()
    except (ValueError, OSError, subprocess.CalledProcessError, ImportError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
