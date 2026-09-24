"""Source alignment tests only. No acoustic recognition is mocked or graded."""
import unittest
from tool.build_quran_word_mapping import boundary_projection, build_groups

class MappingTests(unittest.TestCase):
    def test_identity(self):
        mapping, cost = boundary_projection('abcdef', 'abcdef', [2, 4])
        self.assertEqual(mapping, {2: 2, 4: 4})
        self.assertEqual(cost, 0)

    def test_ambiguous_repeat_does_not_claim_boundary(self):
        mapping, _ = boundary_projection('aa', 'a', [1])
        self.assertNotIn(1, mapping)

    def test_internal_version_change_preserves_unique_boundary(self):
        mapping, cost = boundary_projection('xaabc', 'xabc', [3])
        self.assertEqual(mapping, {3: 2})
        self.assertEqual(cost, 1)

    def test_large_reference_drift_fails_closed(self):
        with self.assertRaises(ValueError):
            boundary_projection('aaaaaaaaaa', 'bbbbbbbbbb', [5])

    def test_changed_display_text_fails_closed(self):
        with self.assertRaises(AssertionError):
            build_groups({'aya_text': 'بِسْمِ', 'aya_phoneme': 'بِسمِ'},
                {'words': [{'text': 'قُل', 'phonemes': ['بِ', 'س', 'مِ']}]}, 1)

if __name__ == '__main__':
    unittest.main()
