#!/usr/bin/env python3
"""
Generates a minimal but complete TidyUp.xcodeproj/project.pbxproj.
Run from the /Users/light/Documents/projects/tidyup directory.
"""

import os, uuid, hashlib

# ─── helpers ────────────────────────────────────────────────────────────────

def new_id():
    """Return a 24-char uppercase hex string usable as a PBX object key."""
    return hashlib.md5(uuid.uuid4().bytes).hexdigest()[:24].upper()

# ─── collect source files ────────────────────────────────────────────────────

BASE = "/Users/light/Documents/projects/tidyup"
SRC_ROOT = os.path.join(BASE, "TidyUp")
TEST_ROOT = os.path.join(BASE, "TidyUpTests")

def collect_swift(directory):
    files = []
    for root, _, fnames in os.walk(directory):
        for f in fnames:
            if f.endswith(".swift"):
                abs_path = os.path.join(root, f)
                rel_path = os.path.relpath(abs_path, BASE)
                files.append((f, rel_path, abs_path))
    return sorted(files)

main_files  = collect_swift(SRC_ROOT)
test_files  = collect_swift(TEST_ROOT)

# ─── assign stable IDs ───────────────────────────────────────────────────────

# Top-level IDs
PROJECT_ID          = new_id()
MAIN_GROUP_ID       = new_id()
PRODUCTS_GROUP_ID   = new_id()

TARGET_APP_ID       = new_id()
TARGET_TEST_ID      = new_id()

CONFIG_LIST_PROJ_ID = new_id()
CONFIG_LIST_APP_ID  = new_id()
CONFIG_LIST_TEST_ID = new_id()

CONFIG_DEBUG_PROJ   = new_id()
CONFIG_RELEASE_PROJ = new_id()
CONFIG_DEBUG_APP    = new_id()
CONFIG_RELEASE_APP  = new_id()
CONFIG_DEBUG_TEST   = new_id()
CONFIG_RELEASE_TEST = new_id()

BUILD_PHASE_SOURCES_APP  = new_id()
BUILD_PHASE_FWORKS_APP   = new_id()
BUILD_PHASE_RESOURCES_APP = new_id()
BUILD_PHASE_SOURCES_TEST = new_id()
BUILD_PHASE_FWORKS_TEST  = new_id()

APP_PRODUCT_ID      = new_id()
TEST_PRODUCT_ID     = new_id()

INFOPLIST_FILE_REF  = new_id()

# Per-file IDs: (filename, rel_path) → (fileRef, buildFile)
def make_file_ids(files):
    return {rel: (new_id(), new_id()) for _, rel, _ in files}

main_ids = make_file_ids(main_files)
test_ids = make_file_ids(test_files)

# Group IDs for folder structure
TIDYUP_GROUP_ID     = new_id()

# ─── write pbxproj ───────────────────────────────────────────────────────────

def q(s):
    """Quote a string for pbxproj."""
    if any(c in s for c in ' /.-@()[]{}'):
        return f'"{s}"'
    return s

lines = ["// !$*UTF8*$!", "{"]

def s(indent, text=""):
    lines.append("\t" * indent + text)

s(1, "archiveVersion = 1;")
s(1, "classes = {")
s(1, "};")
s(1, "objectVersion = 56;")
s(1, "objects = {")
s(0)

# ── PBXBuildFile ────────────────────────────────────────────────────────────
s(2, "/* Begin PBXBuildFile section */")
for fname, rel, _ in main_files:
    fref_id, bf_id = main_ids[rel]
    s(2, f"{bf_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref_id} /* {fname} */; }};")
for fname, rel, _ in test_files:
    fref_id, bf_id = test_ids[rel]
    s(2, f"{bf_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref_id} /* {fname} */; }};")
s(2, "/* End PBXBuildFile section */")
s(0)

# ── PBXFileReference ────────────────────────────────────────────────────────
s(2, "/* Begin PBXFileReference section */")
for fname, rel, _ in main_files:
    fref_id, _ = main_ids[rel]
    s(2, f'{fref_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT; }};')
for fname, rel, _ in test_files:
    fref_id, _ = test_ids[rel]
    s(2, f'{fref_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT; }};')
# App product
s(2, f'{APP_PRODUCT_ID} /* TidyUp.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TidyUp.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
s(2, f'{TEST_PRODUCT_ID} /* TidyUpTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TidyUpTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
# Info.plist
s(2, f'{INFOPLIST_FILE_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "TidyUp/Resources/Info.plist"; sourceTree = SOURCE_ROOT; }};')
s(2, "/* End PBXFileReference section */")
s(0)

# ── PBXFrameworksBuildPhase ──────────────────────────────────────────────────
s(2, "/* Begin PBXFrameworksBuildPhase section */")
s(2, f"{BUILD_PHASE_FWORKS_APP} /* Frameworks */ = {{")
s(3, "isa = PBXFrameworksBuildPhase;")
s(3, "buildActionMask = 2147483647;")
s(3, "files = (")
s(3, ");")
s(3, "runOnlyForDeploymentPostprocessing = 0;")
s(2, "};")
s(2, f"{BUILD_PHASE_FWORKS_TEST} /* Frameworks */ = {{")
s(3, "isa = PBXFrameworksBuildPhase;")
s(3, "buildActionMask = 2147483647;")
s(3, "files = (")
s(3, ");")
s(3, "runOnlyForDeploymentPostprocessing = 0;")
s(2, "};")
s(2, "/* End PBXFrameworksBuildPhase section */")
s(0)

# ── PBXGroup ─────────────────────────────────────────────────────────────────
# Recursive group builder — group by directory
import collections

def build_group_tree(files, root_label, root_id):
    """
    Returns a dict of group_id -> (label, parent_path, [child_ids])
    where child_ids are either file ref IDs or sub-group IDs.
    """
    # Collect directories
    dir_to_files = collections.defaultdict(list)
    for fname, rel, _ in files:
        reldir = os.path.relpath(os.path.dirname(rel), "TidyUp")
        dir_to_files[reldir].append((fname, rel))

    # Assign IDs per directory
    dir_ids = {".": root_id}
    for d in sorted(dir_to_files.keys()):
        if d != ".":
            dir_ids[d] = new_id()

    return dir_ids, dir_to_files

main_dir_ids, main_dir_files = build_group_tree(main_files, "TidyUp", TIDYUP_GROUP_ID)

s(2, "/* Begin PBXGroup section */")

# Products group
s(2, f"{PRODUCTS_GROUP_ID} /* Products */ = {{")
s(3, "isa = PBXGroup;")
s(3, "children = (")
s(4, f"{APP_PRODUCT_ID} /* TidyUp.app */,")
s(4, f"{TEST_PRODUCT_ID} /* TidyUpTests.xctest */,")
s(3, ");")
s(3, 'name = Products;')
s(3, 'sourceTree = "<group>";')
s(2, "};")

# Main project group
s(2, f"{MAIN_GROUP_ID} = {{")
s(3, "isa = PBXGroup;")
s(3, "children = (")
s(4, f"{TIDYUP_GROUP_ID} /* TidyUp */,")

# Test group
TEST_GROUP_ID = new_id()
s(4, f"{TEST_GROUP_ID} /* TidyUpTests */,")
s(4, f"{PRODUCTS_GROUP_ID} /* Products */,")
s(3, ");")
s(3, 'sourceTree = "<group>";')
s(2, "};")

# TidyUp source group — emit sub-groups
visited_dirs = set()

def emit_group(dirpath, group_id, files_in_dir, all_dir_ids, all_dir_files, all_file_ids, base_label):
    children = []
    # Add subdirectory groups
    for d, gid in sorted(all_dir_ids.items()):
        parent = os.path.dirname(d)
        if parent == dirpath and d != dirpath:
            children.append((gid, os.path.basename(d)))
    # Add files in this dir
    for fname, rel in sorted(files_in_dir.get(dirpath, [])):
        fref_id, _ = all_file_ids[rel]
        children.append((fref_id, fname))

    label = base_label if dirpath == "." else os.path.basename(dirpath)

    s(2, f"{group_id} /* {label} */ = {{")
    s(3, "isa = PBXGroup;")
    s(3, "children = (")
    for cid, clabel in children:
        s(4, f"{cid} /* {clabel} */,")
    if dirpath == ".":
        s(4, f"{INFOPLIST_FILE_REF} /* Info.plist */,")
    s(3, ");")
    s(3, f"name = {q(label)};")
    s(3, 'sourceTree = "<group>";')
    s(2, "};")

# Emit all TidyUp groups
all_dirs = set(main_dir_ids.keys())
for d in sorted(all_dirs):
    emit_group(d, main_dir_ids[d], main_dir_files, main_dir_ids, main_dir_files, main_ids, "TidyUp")

# Test group
test_file_ids = test_ids
s(2, f"{TEST_GROUP_ID} /* TidyUpTests */ = {{")
s(3, "isa = PBXGroup;")
s(3, "children = (")
for fname, rel, _ in test_files:
    fref_id, _ = test_file_ids[rel]
    s(4, f"{fref_id} /* {fname} */,")
s(3, ");")
s(3, 'name = TidyUpTests;')
s(3, 'path = TidyUpTests;')
s(3, 'sourceTree = "<group>";')
s(2, "};")

s(2, "/* End PBXGroup section */")
s(0)

# ── PBXNativeTarget ──────────────────────────────────────────────────────────
s(2, "/* Begin PBXNativeTarget section */")

s(2, f"{TARGET_APP_ID} /* TidyUp */ = {{")
s(3, "isa = PBXNativeTarget;")
s(3, f"buildConfigurationList = {CONFIG_LIST_APP_ID} /* Build configuration list for PBXNativeTarget TidyUp */;")
s(3, "buildPhases = (")
s(4, f"{BUILD_PHASE_SOURCES_APP} /* Sources */,")
s(4, f"{BUILD_PHASE_FWORKS_APP} /* Frameworks */,")
s(4, f"{BUILD_PHASE_RESOURCES_APP} /* Resources */,")
s(3, ");")
s(3, "buildRules = (")
s(3, ");")
s(3, "dependencies = (")
s(3, ");")
s(3, 'name = TidyUp;')
s(3, 'productName = TidyUp;')
s(3, f"productReference = {APP_PRODUCT_ID} /* TidyUp.app */;")
s(3, 'productType = "com.apple.product-type.application";')
s(2, "};")

s(2, f"{TARGET_TEST_ID} /* TidyUpTests */ = {{")
s(3, "isa = PBXNativeTarget;")
s(3, f"buildConfigurationList = {CONFIG_LIST_TEST_ID} /* Build configuration list for PBXNativeTarget TidyUpTests */;")
s(3, "buildPhases = (")
s(4, f"{BUILD_PHASE_SOURCES_TEST} /* Sources */,")
s(4, f"{BUILD_PHASE_FWORKS_TEST} /* Frameworks */,")
s(3, ");")
s(3, "buildRules = (")
s(3, ");")
s(3, "dependencies = (")
s(3, ");")
s(3, 'name = TidyUpTests;')
s(3, 'productName = TidyUpTests;')
s(3, f"productReference = {TEST_PRODUCT_ID} /* TidyUpTests.xctest */;")
s(3, 'productType = "com.apple.product-type.bundle.unit-test";')
s(2, "};")

s(2, "/* End PBXNativeTarget section */")
s(0)

# ── PBXProject ───────────────────────────────────────────────────────────────
s(2, "/* Begin PBXProject section */")
s(2, f"{PROJECT_ID} /* Project object */ = {{")
s(3, "isa = PBXProject;")
s(3, "attributes = {")
s(4, "BuildIndependentTargetsInParallel = 1;")
s(4, "LastSwiftUpdateCheck = 1600;")
s(4, "LastUpgradeCheck = 1600;")
s(4, "TargetAttributes = {")
s(5, f"{TARGET_APP_ID} = {{")
s(6, "CreatedOnToolsVersion = 16.0;")
s(5, "};")
s(5, f"{TARGET_TEST_ID} = {{")
s(6, "CreatedOnToolsVersion = 16.0;")
s(5, "};")
s(4, "};")
s(3, "};")
s(3, f"buildConfigurationList = {CONFIG_LIST_PROJ_ID} /* Build configuration list for PBXProject TidyUp */;")
s(3, 'compatibilityVersion = "Xcode 14.0";')
s(3, 'developmentRegion = en;')
s(3, 'hasScannedForEncodings = 0;')
s(3, 'knownRegions = (')
s(4, 'en,')
s(4, 'Base,')
s(3, ');')
s(3, f'mainGroup = {MAIN_GROUP_ID};')
s(3, f'productRefGroup = {PRODUCTS_GROUP_ID} /* Products */;')
s(3, 'projectDirPath = "";')
s(3, 'projectRoot = "";')
s(3, 'targets = (')
s(4, f'{TARGET_APP_ID} /* TidyUp */,')
s(4, f'{TARGET_TEST_ID} /* TidyUpTests */,')
s(3, ');')
s(2, "};")
s(2, "/* End PBXProject section */")
s(0)

# ── PBXResourcesBuildPhase ───────────────────────────────────────────────────
s(2, "/* Begin PBXResourcesBuildPhase section */")
s(2, f"{BUILD_PHASE_RESOURCES_APP} /* Resources */ = {{")
s(3, "isa = PBXResourcesBuildPhase;")
s(3, "buildActionMask = 2147483647;")
s(3, "files = (")
s(3, ");")
s(3, "runOnlyForDeploymentPostprocessing = 0;")
s(2, "};")
s(2, "/* End PBXResourcesBuildPhase section */")
s(0)

# ── PBXSourcesBuildPhase ─────────────────────────────────────────────────────
s(2, "/* Begin PBXSourcesBuildPhase section */")

s(2, f"{BUILD_PHASE_SOURCES_APP} /* Sources */ = {{")
s(3, "isa = PBXSourcesBuildPhase;")
s(3, "buildActionMask = 2147483647;")
s(3, "files = (")
for fname, rel, _ in main_files:
    _, bf_id = main_ids[rel]
    s(4, f"{bf_id} /* {fname} in Sources */,")
s(3, ");")
s(3, "runOnlyForDeploymentPostprocessing = 0;")
s(2, "};")

s(2, f"{BUILD_PHASE_SOURCES_TEST} /* Sources */ = {{")
s(3, "isa = PBXSourcesBuildPhase;")
s(3, "buildActionMask = 2147483647;")
s(3, "files = (")
for fname, rel, _ in test_files:
    _, bf_id = test_ids[rel]
    s(4, f"{bf_id} /* {fname} in Sources */,")
s(3, ");")
s(3, "runOnlyForDeploymentPostprocessing = 0;")
s(2, "};")

s(2, "/* End PBXSourcesBuildPhase section */")
s(0)

# ── XCBuildConfiguration ─────────────────────────────────────────────────────

def emit_config(cfg_id, name, is_app, is_test=False):
    s(2, f"{cfg_id} /* {name} */ = {{")
    s(3, "isa = XCBuildConfiguration;")
    s(3, "buildSettings = {")
    if is_app:
        s(4, 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
        s(4, 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;')
        s(4, 'CODE_SIGN_STYLE = Automatic;')
        s(4, 'CURRENT_PROJECT_VERSION = 1;')
        s(4, 'DEVELOPMENT_TEAM = "";')
        s(4, 'GENERATE_INFOPLIST_FILE = YES;')
        s(4, 'INFOPLIST_FILE = "TidyUp/Resources/Info.plist";')
        s(4, 'INFOPLIST_KEY_NSContactsUsageDescription = "TidyUp needs Contacts access to find and merge duplicate contacts on your device.";')
        s(4, 'INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "TidyUp needs read/write access to scan for similar photos, screenshots, and large videos.";')
        s(4, 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;')
        s(4, 'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;')
        s(4, 'INFOPLIST_KEY_UILaunchScreen_Generation = YES;')
        s(4, 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;')
        s(4, 'IPHONEOS_DEPLOYMENT_TARGET = 26.0;')
        s(4, 'MARKETING_VERSION = 1.0;')
        s(4, 'PRODUCT_BUNDLE_IDENTIFIER = "com.tidyup.app";')
        s(4, 'PRODUCT_NAME = TidyUp;')
        s(4, 'SWIFT_EMIT_LOC_STRINGS = YES;')
        s(4, 'SWIFT_VERSION = 6.0;')
        s(4, 'TARGETED_DEVICE_FAMILY = 1;')
    elif is_test:
        s(4, 'BUNDLE_LOADER = "$(TEST_HOST)";')
        s(4, 'CODE_SIGN_STYLE = Automatic;')
        s(4, 'CURRENT_PROJECT_VERSION = 1;')
        s(4, 'GENERATE_INFOPLIST_FILE = YES;')
        s(4, 'IPHONEOS_DEPLOYMENT_TARGET = 26.0;')
        s(4, 'MARKETING_VERSION = 1.0;')
        s(4, 'PRODUCT_BUNDLE_IDENTIFIER = "com.tidyup.app.tests";')
        s(4, 'PRODUCT_NAME = TidyUpTests;')
        s(4, 'SWIFT_VERSION = 6.0;')
        s(4, f'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/TidyUp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TidyUp";')
        s(4, 'TARGETED_DEVICE_FAMILY = 1;')
    else:
        # project-level
        s(4, 'ALWAYS_SEARCH_USER_PATHS = NO;')
        if name == "Debug":
            s(4, 'DEBUG_INFORMATION_FORMAT = dwarf;')
            s(4, 'ENABLE_TESTABILITY = YES;')
            s(4, 'GCC_DYNAMIC_NO_PIC = NO;')
            s(4, 'GCC_OPTIMIZATION_LEVEL = 0;')
            s(4, 'ONLY_ACTIVE_ARCH = YES;')
            s(4, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
            s(4, 'SWIFT_OPTIMIZATION_LEVEL = "-Onone";')
        else:
            s(4, 'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
            s(4, 'SWIFT_OPTIMIZATION_LEVEL = "-O";')
        s(4, 'CLANG_ANALYZER_NONNULL = YES;')
        s(4, 'CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;')
        s(4, 'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";')
        s(4, 'CLANG_ENABLE_MODULES = YES;')
        s(4, 'CLANG_ENABLE_OBJC_ARC = YES;')
        s(4, 'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;')
        s(4, 'CLANG_WARN_BOOL_CONVERSION = YES;')
        s(4, 'CLANG_WARN_COMMA = YES;')
        s(4, 'CLANG_WARN_CONSTANT_CONVERSION = YES;')
        s(4, 'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;')
        s(4, 'CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;')
        s(4, 'CLANG_WARN_DOCUMENTATION_COMMENTS = YES;')
        s(4, 'CLANG_WARN_EMPTY_BODY = YES;')
        s(4, 'CLANG_WARN_ENUM_CONVERSION = YES;')
        s(4, 'CLANG_WARN_INFINITE_RECURSION = YES;')
        s(4, 'CLANG_WARN_INT_CONVERSION = YES;')
        s(4, 'CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;')
        s(4, 'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;')
        s(4, 'CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;')
        s(4, 'CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;')
        s(4, 'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;')
        s(4, 'CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;')
        s(4, 'CLANG_WARN_STRICT_PROTOTYPES = YES;')
        s(4, 'CLANG_WARN_SUSPICIOUS_MOVE = YES;')
        s(4, 'CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;')
        s(4, 'CLANG_WARN_UNREACHABLE_CODE = YES;')
        s(4, 'CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;')
        s(4, 'COPY_PHASE_STRIP = NO;')
        s(4, 'ENABLE_STRICT_OBJC_MSGSEND = YES;')
        s(4, 'GCC_C_LANGUAGE_STANDARD = gnu17;')
        s(4, 'GCC_NO_COMMON_BLOCKS = YES;')
        s(4, 'GCC_WARN_64_TO_32_BIT_CONVERSION = YES;')
        s(4, 'GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;')
        s(4, 'GCC_WARN_UNDECLARED_SELECTOR = YES;')
        s(4, 'GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;')
        s(4, 'GCC_WARN_UNUSED_FUNCTION = YES;')
        s(4, 'GCC_WARN_UNUSED_VARIABLE = YES;')
        s(4, 'IPHONEOS_DEPLOYMENT_TARGET = 26.0;')
        s(4, 'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;' if name == "Debug" else 'MTL_ENABLE_DEBUG_INFO = NO;')
        s(4, 'SDKROOT = iphoneos;')
        s(4, 'SWIFT_STRICT_CONCURRENCY = complete;')
    s(3, "};")
    s(3, f'name = {name};')
    s(2, "};")

s(2, "/* Begin XCBuildConfiguration section */")
emit_config(CONFIG_DEBUG_PROJ,   "Debug",   False)
emit_config(CONFIG_RELEASE_PROJ, "Release", False)
emit_config(CONFIG_DEBUG_APP,    "Debug",   True)
emit_config(CONFIG_RELEASE_APP,  "Release", True)
emit_config(CONFIG_DEBUG_TEST,   "Debug",   False, is_test=True)
emit_config(CONFIG_RELEASE_TEST, "Release", False, is_test=True)
s(2, "/* End XCBuildConfiguration section */")
s(0)

# ── XCConfigurationList ───────────────────────────────────────────────────────
s(2, "/* Begin XCConfigurationList section */")

s(2, f"{CONFIG_LIST_PROJ_ID} /* Build configuration list for PBXProject TidyUp */ = {{")
s(3, "isa = XCConfigurationList;")
s(3, "buildConfigurations = (")
s(4, f"{CONFIG_DEBUG_PROJ} /* Debug */,")
s(4, f"{CONFIG_RELEASE_PROJ} /* Release */,")
s(3, ");")
s(3, 'defaultConfigurationIsVisible = 0;')
s(3, 'defaultConfigurationName = Release;')
s(2, "};")

s(2, f"{CONFIG_LIST_APP_ID} /* Build configuration list for PBXNativeTarget TidyUp */ = {{")
s(3, "isa = XCConfigurationList;")
s(3, "buildConfigurations = (")
s(4, f"{CONFIG_DEBUG_APP} /* Debug */,")
s(4, f"{CONFIG_RELEASE_APP} /* Release */,")
s(3, ");")
s(3, 'defaultConfigurationIsVisible = 0;')
s(3, 'defaultConfigurationName = Release;')
s(2, "};")

s(2, f"{CONFIG_LIST_TEST_ID} /* Build configuration list for PBXNativeTarget TidyUpTests */ = {{")
s(3, "isa = XCConfigurationList;")
s(3, "buildConfigurations = (")
s(4, f"{CONFIG_DEBUG_TEST} /* Debug */,")
s(4, f"{CONFIG_RELEASE_TEST} /* Release */,")
s(3, ");")
s(3, 'defaultConfigurationIsVisible = 0;')
s(3, 'defaultConfigurationName = Release;')
s(2, "};")

s(2, "/* End XCConfigurationList section */")
s(0)

# ── Close ────────────────────────────────────────────────────────────────────
s(1, "};")
s(1, f"rootObject = {PROJECT_ID} /* Project object */;")
lines.append("}")

# ── Write file ────────────────────────────────────────────────────────────────
proj_dir = os.path.join(BASE, "TidyUp.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
out_path = os.path.join(proj_dir, "project.pbxproj")
with open(out_path, "w") as f:
    f.write("\n".join(lines))

print(f"✅ Generated {out_path}")
print(f"   App sources:  {len(main_files)} files")
print(f"   Test sources: {len(test_files)} files")
