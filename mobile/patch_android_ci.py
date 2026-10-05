import os
import re

base_dir = os.path.dirname(os.path.abspath(__file__))
android_dir = os.path.join(base_dir, "android")

def patch_manifest(path: str):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if 'xmlns:tools="http://schemas.android.com/tools"' not in content:
        content = content.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"'
        )

    if 'tools:replace="android:allowBackup"' not in content:
        content = content.replace(
            '<application',
            '<application tools:replace="android:allowBackup" android:allowBackup="false"'
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Patched {path}")

def patch_settings(path: str):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "org.jetbrains.kotlin.android" in content:
        content = re.sub(
            r'org\.jetbrains\.kotlin\.android[\"\x27]\s+version\s+[\"\x27][^\"\x27]+[\"\x27]',
            'org.jetbrains.kotlin.android" version "1.9.24"',
            content
        )
    elif "plugins {" in content:
        content = content.replace(
            "plugins {",
            "plugins {\n    id \"org.jetbrains.kotlin.android\" version \"1.9.24\" apply false"
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Patched {path}")

def patch_app_build(path: str):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Safely ensure minSdk is at least 21 without corrupting flutter.minSdkVersion
    content = re.sub(r'minSdkVersion\s+([0-9]+)', lambda m: f'minSdkVersion {max(21, int(m.group(1)))}', content)
    content = re.sub(r'minSdk\s*=\s*([0-9]+)', lambda m: f'minSdk = {max(21, int(m.group(1)))}', content)

    # Ensure release signing uses debug key for CI release APK build if not already specified
    if "signingConfigs.debug" not in content and "buildTypes {" in content:
        content = re.sub(
            r'buildTypes\s*\{\s*release\s*\{',
            'buildTypes {\n        release {\n            signingConfig signingConfigs.debug',
            content
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Patched {path}")

def patch_root_build(path: str):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "ext.kotlin_version" in content:
        content = re.sub(
            r'ext\.kotlin_version\s*=\s*[\"\x27][^\"\x27]+[\"\x27]',
            'ext.kotlin_version = "1.9.24"',
            content
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Patched {path}")

if __name__ == "__main__":
    patch_manifest(os.path.join(android_dir, "app/src/main/AndroidManifest.xml"))
    patch_settings(os.path.join(android_dir, "settings.gradle"))
    patch_app_build(os.path.join(android_dir, "app/build.gradle"))
    patch_root_build(os.path.join(android_dir, "build.gradle"))
