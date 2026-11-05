import unittest

from names import display_name


class DisplayNameTest(unittest.TestCase):
    def test_joins_parts_with_single_spaces(self) -> None:
        self.assertEqual(display_name("Ada", "Lovelace"), "Ada Lovelace")

    def test_trims_parts_and_leaves_out_blank_ones(self) -> None:
        self.assertEqual(display_name("  Ada ", "", "   ", "Lovelace"), "Ada Lovelace")

    def test_no_parts_gives_an_empty_string(self) -> None:
        self.assertEqual(display_name(), "")


if __name__ == "__main__":
    unittest.main()
