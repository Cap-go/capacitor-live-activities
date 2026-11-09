import pathlib
import re
import tempfile
import unittest
import importlib.util


def load_configure_module():
    path = pathlib.Path(__file__).resolve().parent / "configure-live-activities-target.py"
    spec = importlib.util.spec_from_file_location("configure_live_activities_target", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def strip_live_activities_from_pbxproj(text: str) -> str:
    patterns = [
        r"\t\t[A-F0-9]{24} /\* LiveActivitiesExtension \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* Build configuration list for PBXNativeTarget \"LiveActivitiesExtension\" \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* XCLocalSwiftPackageReference \"CapgoCapacitorLiveActivities\" \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* CapgoLiveActivitiesShared \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* LiveActivities \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* PBXContainerItemProxy \*/ = \{[^\}]*remoteInfo = LiveActivitiesExtension;[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* PBXTargetDependency \*/ = \{[^\}]*LiveActivitiesExtension[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* Embed Foundation Extensions \*/ = \{.*?\n\t\t\};\n",
        r"\t\t[A-F0-9]{24} /\* (?:Sources|Frameworks|Resources) \*/ = \{[^\}]*LiveActivities[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* (?:Sources|Frameworks|Resources) \*/ = \{[^\}]*CapgoLiveActivity[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* Debug \*/ = \{[^\}]*APPLICATION_EXTENSION_API_ONLY = YES;[^\}]*PRODUCT_BUNDLE_IDENTIFIER = app\.capgo\.live\.activities\.LiveActivities;[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* Release \*/ = \{[^\}]*APPLICATION_EXTENSION_API_ONLY = YES;[^\}]*PRODUCT_BUNDLE_IDENTIFIER = app\.capgo\.live\.activities\.LiveActivities;[^\}]*\};\n",
        r"\t\t[A-F0-9]{24} /\* LiveActivitiesExtension\.appex in Embed Foundation Extensions \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* LiveActivitiesExtension\.appex \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* LiveActivitiesBundle\.swift in Sources \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* CapgoLiveActivityWidget\.swift in Sources \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* LiveActivitiesBundle\.swift \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* CapgoLiveActivityWidget\.swift \*/ = \{[^\n]*\};\n",
        r"\t\t[A-F0-9]{24} /\* CapgoLiveActivitiesShared in Frameworks \*/ = \{[^\n]*\};\n",
    ]
    out = text
    for pattern in patterns:
        out = re.sub(pattern, "", out, flags=re.DOTALL)
    out = re.sub(
        r"^\t\t\t\t[A-F0-9]{24} /\* [^\n]*(?:LiveActivities|CapgoLiveActivity|CapgoLiveActivities)[^\n]*\*/,\n",
        "",
        out,
        flags=re.MULTILINE,
    )
    out = out.replace(
        "\t\t504EC3051FED79650016851F /* Products */ = {",
        "\t\t504EC3051FED79650016851F = {",
    )
    out = re.sub(
        r"(\t\t\t\t504EC3021FED79650016851F /\* Resources \*/,\n)"
        r"\t\t\t\t[A-F0-9]{24} /\* Embed Foundation Extensions \*/,\n",
        r"\1",
        out,
    )
    out = re.sub(
        r"\t\t\tdependencies = \(\n\t\t\t\t[A-F0-9]{24} /\* PBXTargetDependency \*/,\n\t\t\t\);",
        "\t\t\tdependencies = (\n\t\t\t);",
        out,
    )
    out = re.sub(r"\t\t\t\tCODE_SIGN_ENTITLEMENTS = App/App\.entitlements;\n", "", out)
    return out


def extension_live_activities_build_settings(pbx: str) -> list[str]:
    blocks = re.findall(
        r"isa = XCBuildConfiguration;\s+buildSettings = \{(.*?)\};\s+name = (?:Debug|Release);",
        pbx,
        flags=re.DOTALL,
    )
    matched: list[str] = []
    for settings in blocks:
        if re.search(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*[^\n]*LiveActivities", settings):
            matched.append(settings)
    return matched


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

    def test_ensure_capapp_ios_platform_fails_on_unrecognized_platform(self):
        module = load_configure_module()
        with tempfile.TemporaryDirectory() as tmp:
            pkg = pathlib.Path(tmp) / "Package.swift"
            pkg.write_text("platforms: [.iOS(.v17)]\n", encoding="utf-8")
            module.CAPAPP_PACKAGE = pkg
            with self.assertRaises(SystemExit):
                module.ensure_capapp_ios_platform()

    def test_extension_build_configs_set_application_extension_api_only(self):
        module = load_configure_module()
        ios_dir = pathlib.Path(__file__).resolve().parent
        source_pbx = ios_dir / "App" / "App.xcodeproj" / "project.pbxproj"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_ios = pathlib.Path(tmp) / "ios"
            proj_dir = tmp_ios / "App" / "App.xcodeproj"
            proj_dir.mkdir(parents=True)
            pbx = proj_dir / "project.pbxproj"
            baseline = strip_live_activities_from_pbxproj(source_pbx.read_text(encoding="utf-8"))
            self.assertNotIn("LiveActivitiesExtension", baseline)
            pbx.write_text(baseline, encoding="utf-8")
            module.PBXPROJ = pbx
            module.APP_INFO_PLIST = tmp_ios / "App" / "App" / "Info.plist"
            module.CAPAPP_PACKAGE = tmp_ios / "App" / "CapApp-SPM" / "Package.swift"
            module.main()
            result = pbx.read_text(encoding="utf-8")
            settings_blocks = extension_live_activities_build_settings(result)
            self.assertGreaterEqual(len(settings_blocks), 2)
            for block in settings_blocks:
                self.assertIn("APPLICATION_EXTENSION_API_ONLY = YES;", block)

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

    def test_main_normalizes_capapp_platform_when_extension_already_configured(self):
        module = load_configure_module()
        ios_dir = pathlib.Path(__file__).resolve().parent
        source_pbx = ios_dir / "App" / "App.xcodeproj" / "project.pbxproj"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_ios = pathlib.Path(tmp) / "ios"
            proj_dir = tmp_ios / "App" / "App.xcodeproj"
            proj_dir.mkdir(parents=True)
            pbx = proj_dir / "project.pbxproj"
            original = source_pbx.read_text(encoding="utf-8")
            self.assertIn("LiveActivitiesExtension", original)
            pbx.write_text(original, encoding="utf-8")
            pkg = tmp_ios / "App" / "CapApp-SPM" / "Package.swift"
            pkg.parent.mkdir(parents=True)
            pkg.write_text("platforms: [.iOS(.v16)]\n", encoding="utf-8")
            module.PBXPROJ = pbx
            module.APP_INFO_PLIST = tmp_ios / "App" / "App" / "Info.plist"
            module.CAPAPP_PACKAGE = pkg
            module.main()
            self.assertEqual(
                pkg.read_text(encoding="utf-8"),
                'platforms: [.iOS("16.1")]\n',
            )
            self.assertEqual(pbx.read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
