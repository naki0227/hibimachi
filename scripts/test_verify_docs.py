import tempfile
import unittest
from pathlib import Path
from verify_docs import validate


class DocsQualityTest(unittest.TestCase):
    def test_project_docs_are_valid(self):
        self.assertEqual([], validate())

    def test_missing_files_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            failures = validate(Path(directory))
            self.assertTrue(any(x.startswith("Missing required file") for x in failures))


if __name__ == "__main__":
    unittest.main()
