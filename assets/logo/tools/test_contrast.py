"""Tests for the WCAG contrast helper. Stdlib only — no pytest dependency."""
import unittest

from contrast import contrast_ratio, relative_luminance


class TestRelativeLuminance(unittest.TestCase):
    def test_white_is_one(self):
        self.assertAlmostEqual(relative_luminance("#FFFFFF"), 1.0, places=6)

    def test_black_is_zero(self):
        self.assertAlmostEqual(relative_luminance("#000000"), 0.0, places=6)

    def test_accepts_hex_without_hash(self):
        self.assertAlmostEqual(
            relative_luminance("FFFFFF"), relative_luminance("#FFFFFF"), places=9
        )

    def test_rejects_short_hex(self):
        with self.assertRaises(ValueError):
            relative_luminance("#FFF")

    def test_rejects_non_hex(self):
        with self.assertRaises(ValueError):
            relative_luminance("#GGGGGG")

    def test_mid_tone_grey(self):
        # #808080 (128/255) tests the sRGB gamma decode curve.
        # This is the critical mid-tone that catches gamma bugs.
        # Correct gamma decode: ((0.5019608+0.055)/1.055)^2.4 ≈ 0.21586050
        self.assertAlmostEqual(relative_luminance("#808080"), 0.21586050, places=5)

    def test_primary_red(self):
        # Full red channel = 1.0 after gamma decode (no gamma effect at endpoints).
        # Tests the luminance coefficient for red: 0.2126.
        self.assertAlmostEqual(relative_luminance("#FF0000"), 0.2126, places=9)

    def test_primary_green(self):
        # Full green channel = 1.0 after gamma decode (no gamma effect at endpoints).
        # Tests the luminance coefficient for green: 0.7152.
        self.assertAlmostEqual(relative_luminance("#00FF00"), 0.7152, places=9)

    def test_primary_blue(self):
        # Full blue channel = 1.0 after gamma decode (no gamma effect at endpoints).
        # Tests the luminance coefficient for blue: 0.0722.
        self.assertAlmostEqual(relative_luminance("#0000FF"), 0.0722, places=9)


class TestContrastRatio(unittest.TestCase):
    def test_black_on_white_is_21(self):
        self.assertAlmostEqual(contrast_ratio("#000000", "#FFFFFF"), 21.0, places=2)

    def test_identical_colours_are_1(self):
        self.assertAlmostEqual(contrast_ratio("#2FBF71", "#2FBF71"), 1.0, places=9)

    def test_is_symmetric(self):
        self.assertAlmostEqual(
            contrast_ratio("#0D1117", "#E8EAED"),
            contrast_ratio("#E8EAED", "#0D1117"),
            places=9,
        )

    def test_ratio_never_below_one(self):
        for fg, bg in [("#0D1117", "#000000"), ("#FFFFFF", "#E8EAED")]:
            self.assertGreaterEqual(contrast_ratio(fg, bg), 1.0)

    def test_mid_tone_contrast(self):
        # #808080 vs #FFFFFF tests gamma decode in a realistic contrast scenario.
        # With correct gamma: (1.05 / (0.21586050 + 0.05)) ≈ 3.94944
        # With mutated decode (no gamma): (1.05 / 0.55196) ≈ 1.90205 (dramatically different)
        self.assertAlmostEqual(contrast_ratio("#808080", "#FFFFFF"), 3.94944, places=3)


if __name__ == "__main__":
    unittest.main()
