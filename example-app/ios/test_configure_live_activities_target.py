import pathlib
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


if __name__ == "__main__":
    unittest.main()
