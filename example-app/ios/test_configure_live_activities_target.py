import pathlib
import tempfile
import unittest
import importlib.util


def load_configure_module():
    path = pathlib.Path(__file__).resolve().parent / "configure-live-activities-target.py"
    spec = importlib.util.spec_from_file_location("configure_live_activities_target", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ConfigureLiveActivitiesTargetTests(unittest.TestCase):
    def test_app_info_plist_path_points_at_app_target_plist(self):
        module = load_configure_module()
        ios_dir = pathlib.Path(__file__).resolve().parent
        pbxproj = ios_dir / "App" / "App.xcodeproj" / "project.pbxproj"
        expected = ios_dir / "App" / "App" / "Info.plist"
        self.assertEqual(module.app_info_plist_path(pbxproj), expected)
        self.assertTrue(expected.is_file())

    def test_ensure_capapp_ios_platform_rewrites_v16_to_16_1(self):
        module = load_configure_module()
        with tempfile.TemporaryDirectory() as tmp:
            pkg = pathlib.Path(tmp) / "Package.swift"
            pkg.write_text("platforms: [.iOS(.v16)]\n", encoding="utf-8")
            module.CAPAPP_PACKAGE = pkg
            module.ensure_capapp_ios_platform()
            self.assertEqual(
                pkg.read_text(encoding="utf-8"),
                'platforms: [.iOS("16.1")]\n',
            )

    def test_ensure_live_activities_info_plist_adds_key_with_true_value(self):
        module = load_configure_module()
        with tempfile.TemporaryDirectory() as tmp:
            plist = pathlib.Path(tmp) / "Info.plist"
            plist.write_text(
                "\t<key>UIViewControllerBasedStatusBarAppearance</key>\n\t<true/>\n",
                encoding="utf-8",
            )
            module.APP_INFO_PLIST = plist
            module.ensure_live_activities_info_plist()
            self.assertIn(
                "<key>NSSupportsLiveActivities</key>\n\t<true/>",
                plist.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
