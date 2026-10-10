import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("release", Path(__file__).resolve().parents[1] / "scripts/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_forever_does_not_accept_retail_or_classic(self):
        for type_id in (517, 67408):
            with self.assertRaises(ValueError):
                release.forever_version([{"id": 99, "name": "1.60.1", "gameVersionTypeID": type_id}])

    def test_no_fallback_to_other_forever_version(self):
        with self.assertRaises(ValueError):
            release.forever_version([{"id": 99, "name": "1.60.0", "gameVersionTypeID": 88568}])

    def test_unique_exact_forever_version(self):
        row = {"id": 99, "name": "1.60.1", "gameVersionTypeID": 88568}
        self.assertEqual(release.forever_version([row]), 99)
        with self.assertRaises(ValueError):
            release.forever_version([row, row])

    def test_tag_must_match_toc(self):
        with patch.dict(release.os.environ, {"GITHUB_REF_TYPE": "tag", "GITHUB_REF_NAME": "v9.9.9"}):
            with self.assertRaises(ValueError):
                release.release_tag("1.4.1")

    def test_unsafe_toc_path(self):
        with self.assertRaises(ValueError):
            release.toc(b"## Interface: 16001\n## Version: 1.4.1\n../bad.lua\n")

    def test_lua_is_compiled_not_executed(self):
        release.lua_check(b"error('must not execute')", "valid.lua")
        with self.assertRaises(ValueError):
            release.lua_check(b"local =", "invalid.lua")

    def test_missing_and_nested_zip_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".release").mkdir()
            for name in ("QuestItemQuests/QuestItemQuests/test.lua", "QuestItemQuests/extra.lua"):
                with zipfile.ZipFile(root / ".release/test.zip", "w") as z:
                    z.writestr(name, "")
                with patch.object(release, "ROOT", root), patch.object(release, "sources", return_value=({}, {"test.lua"})):
                    with self.assertRaises(ValueError):
                        release.verify()

    def test_existing_claim_prevents_upload(self):
        cfg = release.config() | {"curseforge_project_id": 123}
        archive = Path(__file__)
        env = {"GITHUB_EVENT_NAME": "push", "GITHUB_REF_TYPE": "tag", "CF_API_TOKEN": "test-only", "GH_TOKEN": "test-only", "GITHUB_REPOSITORY": "Evilion1644/QuestItemQuests"}
        with patch.dict(release.os.environ, env), \
             patch.object(release, "verify", return_value=(archive, {"Version": "1.4.1"})), \
             patch.object(release, "release_tag", return_value="v1.4.1"), \
             patch.object(release, "config", return_value=cfg), \
             patch.object(release, "git", return_value="a" * 40), \
             patch.object(Path, "read_text", return_value="# QuestItemQuests 1.4.1\n"), \
             patch.object(release, "request_json", side_effect=[[{"id": 99, "name": "1.60.1", "gameVersionTypeID": 88568}], ValueError("claim already exists")]), \
             patch.object(release.urllib.request, "urlopen") as upload:
            with self.assertRaisesRegex(ValueError, "claim already exists"):
                release.publish()
            upload.assert_not_called()


if __name__ == "__main__":
    unittest.main()
