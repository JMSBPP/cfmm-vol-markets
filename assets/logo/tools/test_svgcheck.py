"""Tests for the SVG invariant checker, using synthetic fixtures."""
import pathlib
import tempfile
import unittest

from svgcheck import check_file, same_shape

CURVE_A = "M 64 448 C 160 448 320 288 320 128"
CURVE_A_SCALED = "M 128 896 C 320 896 640 576 640 256"          # x2 uniform
CURVE_A_SQUASHED = "M 64 224 C 160 224 320 144 320 64"           # y halved
CURVE_B = "M 64 448 C 240 448 300 400 320 128"                   # different shape


def _svg(body: str, view_box: str = "0 0 512 512") -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}">'
        f"{body}</svg>"
    )


def _write(text: str) -> pathlib.Path:
    fh = tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False)
    fh.write(text)
    fh.close()
    return pathlib.Path(fh.name)


class TestSameShape(unittest.TestCase):
    def test_identical_paths_match(self):
        self.assertTrue(same_shape(CURVE_A, CURVE_A))

    def test_uniform_scale_matches(self):
        self.assertTrue(same_shape(CURVE_A, CURVE_A_SCALED))

    def test_non_uniform_scale_matches(self):
        self.assertTrue(same_shape(CURVE_A, CURVE_A_SQUASHED))

    def test_different_shape_does_not_match(self):
        self.assertFalse(same_shape(CURVE_A, CURVE_B))

    def test_relative_commands_are_rejected(self):
        with self.assertRaises(ValueError):
            same_shape(CURVE_A, "m 0 0 c 10 10 20 20 30 30")

    def test_command_type_is_not_compared_known_limitation(self):
        # KNOWN LIMITATION: same_shape() compares coordinate sequences only.
        # It does NOT inspect command letters. A cubic bezier and a polyline
        # with identical coordinates compare equal. This is acceptable because
        # both curves originate as single-tool duplicates, so command family
        # mismatches cannot arise from sanctioned workflow. If this function is
        # later tightened to compare command types, this test must be deleted
        # and the docstring updated.
        cubic = "M 64 448 C 160 448 320 288 320 128"
        polyline = "M 64 448 L 160 448 L 320 288 L 320 128"
        self.assertTrue(same_shape(cubic, polyline))


class TestCheckFile(unittest.TestCase):
    def test_matching_curves_produce_no_violations(self):
        p = _write(
            _svg(
                f'<path id="curve-source" d="{CURVE_A}"/>'
                f'<path id="curve-target" d="{CURVE_A_SCALED}"/>'
            )
        )
        self.assertEqual(check_file(p, expect_curves=2), [])

    def test_mismatched_curves_are_reported(self):
        p = _write(
            _svg(
                f'<path id="curve-source" d="{CURVE_A}"/>'
                f'<path id="curve-target" d="{CURVE_B}"/>'
            )
        )
        violations = check_file(p, expect_curves=2)
        self.assertTrue(any("curve identity" in v for v in violations))

    def test_wrong_curve_count_is_reported(self):
        p = _write(_svg(f'<path id="curve-source" d="{CURVE_A}"/>'))
        violations = check_file(p, expect_curves=2)
        self.assertTrue(any("expected 2" in v for v in violations))

    def test_font_family_attribute_is_reported(self):
        p = _write(_svg('<path id="curve-source" d="M 0 0 L 1 1" font-family="Arial"/>'))
        violations = check_file(p, expect_curves=1)
        self.assertTrue(any("font" in v.lower() for v in violations))

    def test_font_family_in_style_is_reported(self):
        p = _write(
            _svg('<path id="curve-source" d="M 0 0 L 1 1" style="font-family:Arial"/>')
        )
        violations = check_file(p, expect_curves=1)
        self.assertTrue(any("font" in v.lower() for v in violations))

    def test_text_element_is_reported(self):
        p = _write(_svg(f'<path id="curve-source" d="{CURVE_A}"/><text>Y</text>'))
        violations = check_file(p, expect_curves=1)
        self.assertTrue(any("text element" in v for v in violations))

    def test_wrong_viewbox_is_reported(self):
        p = _write(_svg(f'<path id="curve-source" d="{CURVE_A}"/>', view_box="0 0 500 500"))
        violations = check_file(p, expect_curves=1)
        self.assertTrue(any("viewBox" in v for v in violations))

    def test_zero_expected_curves_skips_identity_check(self):
        p = _write(_svg('<path d="M 0 0 L 1 1"/>'))
        self.assertEqual(check_file(p, expect_curves=0), [])


if __name__ == "__main__":
    unittest.main()
