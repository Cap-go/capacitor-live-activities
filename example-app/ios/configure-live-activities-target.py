#!/usr/bin/env python3
"""Add LiveActivities widget extension target to the Capacitor App Xcode project."""

from __future__ import annotations

import pathlib
import uuid

PBXPROJ = pathlib.Path(__file__).resolve().parent / "App" / "App.xcodeproj" / "project.pbxproj"


def app_info_plist_path(pbxproj: pathlib.Path) -> pathlib.Path:
    return pbxproj.parent.parent / "App" / "Info.plist"


APP_INFO_PLIST = app_info_plist_path(PBXPROJ)
CAPAPP_PACKAGE = PBXPROJ.parent.parent / "CapApp-SPM" / "Package.swift"


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    if old not in text:
        raise SystemExit(f"configure-live-activities-target: anchor not found ({label})")
    updated = text.replace(old, new, 1)
    if updated == text:
        raise SystemExit(f"configure-live-activities-target: replace failed ({label})")
    return updated


def replace_n(text: str, old: str, new: str, count: int, *, label: str) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(
            f"configure-live-activities-target: expected {count} occurrence(s) of {label}, found {found}"
        )
    return text.replace(old, new, count)


def ensure_live_activities_info_plist() -> None:
    if not APP_INFO_PLIST.is_file():
        print("Skipping Info.plist update:", APP_INFO_PLIST, "not found")
        return
    text = APP_INFO_PLIST.read_text(encoding="utf-8")
    if "NSSupportsLiveActivities" in text:
        print("Info.plist already enables Live Activities")
        return
    anchor = "\t<key>UIViewControllerBasedStatusBarAppearance</key>\n\t<true/>"
    insertion = (
        "\t<key>UIViewControllerBasedStatusBarAppearance</key>\n\t<true/>\n"
        "\t<key>NSSupportsLiveActivities</key>\n\t<true/>"
    )
    if anchor not in text:
        raise SystemExit("configure-live-activities-target: Info.plist anchor not found")
    APP_INFO_PLIST.write_text(text.replace(anchor, insertion, 1), encoding="utf-8")
    print("Updated", APP_INFO_PLIST)


def ensure_capapp_ios_platform() -> None:
    if not CAPAPP_PACKAGE.is_file():
        print("Skipping CapApp-SPM update:", CAPAPP_PACKAGE, "not found")
        return
    text = CAPAPP_PACKAGE.read_text(encoding="utf-8")
    updated = text
    for old in ('.iOS(.v15)', '.iOS(.v16)', '.iOS("15.0")', '.iOS("16.0")'):
        updated = updated.replace(old, '.iOS("16.1")')
    if updated == text:
        if '.iOS("16.1")' in text:
            print("CapApp-SPM already targets iOS 16.1")
            return
        print("CapApp-SPM platform string not recognized; leaving unchanged")
        return
    CAPAPP_PACKAGE.write_text(updated, encoding="utf-8")
    print("Updated", CAPAPP_PACKAGE)


def main() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    if "LiveActivitiesExtension" in text:
        print("LiveActivities extension already configured")
        ensure_live_activities_info_plist()
        ensure_capapp_ios_platform()
        return

    ids = {name: uid() for name in [
        "appex", "bundle_swift", "widget_swift", "bundle_build", "widget_build",
        "target", "sources", "frameworks", "resources", "proxy", "dependency",
        "embed_phase", "embed_build", "group", "config_list", "debug_cfg", "release_cfg",
        "pkg_ref", "pkg_product", "pkg_framework_build",
    ]}

    deployment_new = "IPHONEOS_DEPLOYMENT_TARGET = 16.1;"
    for deployment_old in (
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0;",
        "IPHONEOS_DEPLOYMENT_TARGET = 16.0;",
    ):
        deployment_count = text.count(deployment_old)
        if deployment_count:
            text = replace_n(
                text,
                deployment_old,
                deployment_new,
                deployment_count,
                label="IPHONEOS_DEPLOYMENT_TARGET",
            )

    app_frameworks = "504EC3011FED79650016851F"
    products_group = "504EC3051FED79650016851F"
    root_group = "504EC2FB1FED79650016851F"
    project = "504EC2FC1FED79650016851F"
    package_refs = "packageReferences = ("
    targets_list = "targets = ("

    build_file_section = f"""\t\t{ids['bundle_build']} /* LiveActivitiesBundle.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ids['bundle_swift']} /* LiveActivitiesBundle.swift */; }};
\t\t{ids['widget_build']} /* CapgoLiveActivityWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ids['widget_swift']} /* CapgoLiveActivityWidget.swift */; }};
\t\t{ids['embed_build']} /* LiveActivitiesExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {ids['appex']} /* LiveActivitiesExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
\t\t{ids['pkg_framework_build']} /* CapgoLiveActivitiesShared in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids['pkg_product']} /* CapgoLiveActivitiesShared */; }};
"""
    text = replace_once(
        text,
        "/* End PBXBuildFile section */",
        build_file_section + "/* End PBXBuildFile section */",
        label="PBXBuildFile section end",
    )

    file_ref_section = f"""\t\t{ids['appex']} /* LiveActivitiesExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = LiveActivitiesExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ids['bundle_swift']} /* LiveActivitiesBundle.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LiveActivitiesBundle.swift; sourceTree = "<group>"; }};
\t\t{ids['widget_swift']} /* CapgoLiveActivityWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CapgoLiveActivityWidget.swift; sourceTree = "<group>"; }};
"""
    text = replace_once(
        text,
        "/* End PBXFileReference section */",
        file_ref_section + "/* End PBXFileReference section */",
        label="PBXFileReference section end",
    )

    ext_frameworks = f"""\t\t{ids['frameworks']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ids['pkg_framework_build']} /* CapgoLiveActivitiesShared in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    group_section = f"""\t\t{ids['group']} /* LiveActivities */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids['bundle_swift']} /* LiveActivitiesBundle.swift */,
\t\t\t\t{ids['widget_swift']} /* CapgoLiveActivityWidget.swift */,
\t\t\t);
\t\t\tpath = ../LiveActivities;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
    text = replace_once(
        text,
        f"\t\t{root_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (",
        f"\t\t{root_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{ids['group']} /* LiveActivities */,",
        label="root PBXGroup children",
    )
    text = replace_once(
        text,
        "/* End PBXGroup section */",
        group_section + "/* End PBXGroup section */",
        label="PBXGroup section end",
    )

    text = replace_once(
        text,
        f"\t\t{products_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t504EC3041FED79650016851F /* App.app */,",
        f"\t\t{products_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t504EC3041FED79650016851F /* App.app */,\n\t\t\t\t{ids['appex']} /* LiveActivitiesExtension.appex */,",
        label="products PBXGroup children",
    )

    native_target = f"""\t\t{ids['target']} /* LiveActivitiesExtension */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids['config_list']} /* Build configuration list for PBXNativeTarget "LiveActivitiesExtension" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids['sources']} /* Sources */,
\t\t\t\t{ids['frameworks']} /* Frameworks */,
\t\t\t\t{ids['resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = LiveActivitiesExtension;
\t\t\tpackageProductDependencies = (
\t\t\t\t{ids['pkg_product']} /* CapgoLiveActivitiesShared */,
\t\t\t);
\t\t\tproductName = LiveActivitiesExtension;
\t\t\tproductReference = {ids['appex']} /* LiveActivitiesExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
"""
    text = replace_once(
        text,
        "/* End PBXNativeTarget section */",
        native_target + "/* End PBXNativeTarget section */",
        label="PBXNativeTarget section end",
    )

    text = replace_once(
        text,
        """\t\t504EC3031FED79650016851F /* App */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 504EC3161FED79650016851F /* Build configuration list for PBXNativeTarget "App" */;
\t\t\tbuildPhases = (
\t\t\t\t504EC3001FED79650016851F /* Sources */,
\t\t\t\t504EC3011FED79650016851F /* Frameworks */,
\t\t\t\t504EC3021FED79650016851F /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = App;
""",
        f"""\t\t504EC3031FED79650016851F /* App */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 504EC3161FED79650016851F /* Build configuration list for PBXNativeTarget "App" */;
\t\t\tbuildPhases = (
\t\t\t\t504EC3001FED79650016851F /* Sources */,
\t\t\t\t504EC3011FED79650016851F /* Frameworks */,
\t\t\t\t504EC3021FED79650016851F /* Resources */,
\t\t\t\t{ids['embed_phase']} /* Embed Foundation Extensions */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{ids['dependency']} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = App;
""",
        label="App PBXNativeTarget embed phase",
    )

    text = replace_once(
        text,
        targets_list + "\n\t\t\t\t504EC3031FED79650016851F /* App */,\n\t\t\t);",
        targets_list + f"\n\t\t\t\t504EC3031FED79650016851F /* App */,\n\t\t\t\t{ids['target']} /* LiveActivitiesExtension */,\n\t\t\t);",
        label="PBXProject targets list",
    )

    text = replace_once(
        text,
        package_refs + "\n\t\t\t\tD4C12C0A2AAA248700AAC8A2 /* XCLocalSwiftPackageReference \"CapApp-SPM\" */,\n\t\t\t);",
        package_refs + f"\n\t\t\t\tD4C12C0A2AAA248700AAC8A2 /* XCLocalSwiftPackageReference \"CapApp-SPM\" */,\n\t\t\t\t{ids['pkg_ref']} /* XCLocalSwiftPackageReference \"CapgoCapacitorLiveActivities\" */,\n\t\t\t);",
        label="XCLocalSwiftPackageReference list",
    )

    phases = f"""
/* Begin PBXCopyFilesBuildPhase section */
\t\t{ids['embed_phase']} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{ids['embed_build']} /* LiveActivitiesExtension.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXContainerItemProxy section */
\t\t{ids['proxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {project} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['target']};
\t\t\tremoteInfo = LiveActivitiesExtension;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */
\t\t{ids['dependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['target']} /* LiveActivitiesExtension */;
\t\t\ttargetProxy = {ids['proxy']} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */
"""
    text = replace_once(
        text,
        "/* Begin PBXResourcesBuildPhase section */",
        phases + "/* Begin PBXResourcesBuildPhase section */",
        label="PBXResourcesBuildPhase section start",
    )

    ext_resources = f"""\t\t{ids['resources']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    ext_sources = f"""\t\t{ids['sources']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ids['bundle_build']} /* LiveActivitiesBundle.swift in Sources */,
\t\t\t\t{ids['widget_build']} /* CapgoLiveActivityWidget.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    text = replace_once(
        text,
        "/* End PBXResourcesBuildPhase section */",
        ext_resources + "/* End PBXResourcesBuildPhase section */",
        label="PBXResourcesBuildPhase section end",
    )
    text = replace_once(
        text,
        "/* End PBXSourcesBuildPhase section */",
        ext_sources + "/* End PBXSourcesBuildPhase section */",
        label="PBXSourcesBuildPhase section end",
    )
    text = replace_once(
        text,
        "/* End PBXFrameworksBuildPhase section */",
        ext_frameworks + "/* End PBXFrameworksBuildPhase section */",
        label="PBXFrameworksBuildPhase section end",
    )

    configs = f"""\t\t{ids['debug_cfg']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ../LiveActivities/LiveActivities.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tINFOPLIST_FILE = ../LiveActivities/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.1;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.capgo.live.activities.LiveActivities;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ids['release_cfg']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ../LiveActivities/LiveActivities.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tINFOPLIST_FILE = ../LiveActivities/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.1;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.capgo.live.activities.LiveActivities;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{ids['config_list']} /* Build configuration list for PBXNativeTarget "LiveActivitiesExtension" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids['debug_cfg']} /* Debug */,
\t\t\t\t{ids['release_cfg']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
    text = replace_once(
        text,
        "/* End XCBuildConfiguration section */",
        configs + "/* End XCBuildConfiguration section */",
        label="XCBuildConfiguration section end",
    )

    pkg_sections = f"""\t\t{ids['pkg_ref']} /* XCLocalSwiftPackageReference "CapgoCapacitorLiveActivities" */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = "../../node_modules/@capgo/capacitor-live-activities";
\t\t}};
"""
    text = replace_once(
        text,
        "/* End XCLocalSwiftPackageReference section */",
        pkg_sections + "/* End XCLocalSwiftPackageReference section */",
        label="XCLocalSwiftPackageReference section end",
    )

    product_dep = f"""\t\t{ids['pkg_product']} /* CapgoLiveActivitiesShared */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {ids['pkg_ref']} /* XCLocalSwiftPackageReference "CapgoCapacitorLiveActivities" */;
\t\t\tproductName = CapgoLiveActivitiesShared;
\t\t}};
"""
    text = replace_once(
        text,
        "/* End XCSwiftPackageProductDependency section */",
        product_dep + "/* End XCSwiftPackageProductDependency section */",
        label="XCSwiftPackageProductDependency section end",
    )

    entitlements_anchor = (
        "\t\t\tbuildSettings = {\n"
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n"
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;"
    )
    entitlements_replacement = (
        "\t\t\tbuildSettings = {\n"
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n"
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = App/App.entitlements;\n"
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;"
    )
    text = replace_n(
        text,
        entitlements_anchor,
        entitlements_replacement,
        2,
        label="App target CODE_SIGN_ENTITLEMENTS",
    )

    ensure_live_activities_info_plist()
    ensure_capapp_ios_platform()

    PBXPROJ.write_text(text, encoding="utf-8")
    print("Updated", PBXPROJ)


if __name__ == "__main__":
    main()
