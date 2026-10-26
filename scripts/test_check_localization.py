import json
import tempfile
import unittest
from pathlib import Path

import check_localization as checker


class CheckLocalizationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for folder in checker.SOURCES:
            (self.root / folder).mkdir()
        self.catalog = self.root / "Shared" / "Localizable.xcstrings"

    def tearDown(self):
        self.temp.cleanup()

    def write_source(self, text: str):
        (self.root / "Hibimachi" / "View.swift").write_text(text, encoding="utf-8")

    def write_catalog(self, translations: dict[str, str]):
        strings = {
            key: {"localizations": {"en": {"stringUnit": {"state": "translated", "value": value}}}}
            for key, value in translations.items()
        }
        self.catalog.write_text(json.dumps({"sourceLanguage": "ja", "strings": strings}), encoding="utf-8")

    def problems(self):
        return checker.check(self.root, self.catalog)

    def test_localized_positions_with_translations_pass(self):
        self.write_source(
            'Text("やった！")\n'
            'let a = String(localized: "のこり\\(count)")\n'
            'Label(flag ? String(localized: "オン") : String(localized: "オフ"), systemImage: "x")\n'
            '// "コメントは無視"\n'
        )
        self.write_catalog({"やった！": "Did it!", "のこり%lld": "%lld left", "オン": "On", "オフ": "Off"})
        self.assertEqual(self.problems(), [])

    def test_plain_string_literal_is_reported(self):
        self.write_source('let title = "まるい木"\n')
        self.write_catalog({"まるい木": "Round tree"})
        self.assertEqual(len(self.problems()), 1)
        self.assertIn("not localizable here", self.problems()[0])

    def test_bare_ternary_inside_text_is_reported(self):
        # Text(flag ? "a" : "b") builds a String, so neither side is looked up.
        self.write_source('Text(flag ? "オン" : "オフ")\n')
        self.write_catalog({"オン": "On", "オフ": "Off"})
        self.assertEqual(len(self.problems()), 2)

    def test_missing_or_untranslated_entries_are_reported(self):
        self.write_source('Text("図鑑")\nText("アルバム")\n')
        self.write_catalog({"図鑑": "Field guide"})
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn("アルバム", problems[0])

    def test_placeholder_count_must_match(self):
        self.write_source('Text("\\(name)を迎えた\\(count)")\n')
        self.write_catalog({"%@を迎えた%lld": "Welcomed %@"})
        self.assertIn("placeholder count", self.problems()[0])

    def test_escaped_newline_matches_catalog_key(self):
        self.write_source('Text("一行目\\n二行目")\n')
        self.write_catalog({"一行目\n二行目": "first\nsecond"})
        self.assertEqual(self.problems(), [])


if __name__ == "__main__":
    unittest.main()
