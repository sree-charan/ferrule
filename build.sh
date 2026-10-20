#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Sree Charan

# Builds Ferrule, assembles the .app bundle, signs it and (with --install)
# installs it into /Applications.
#
# The bundle is staged in a temporary directory outside ~/Documents: folders synced
# by File Provider gain xattrs (com.apple.provenance etc.) that invalidate codesign.
set -euo pipefail
cd "$(dirname "$0")"

# The icon catalog and the bundle are staged in temp dirs; sweep both however
# the script ends.
ICON_TMP=""
STAGE_TMP=""

cleanup() {
    [[ -n "$ICON_TMP" ]] && rm -rf "$ICON_TMP"
    [[ -n "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
# zsh runs the EXIT trap when the script is hung up, but not when it is
# interrupted or terminated; route those through exit so a Ctrl-C partway
# into the build sweeps like any other ending.
trap 'exit 1' INT TERM HUP

# Flags: --dev builds the local-only "Ferrule (Developer)" variant (its own
# bundle id, so it coexists with the official app); --install puts it in /Applications.
DEV=0
INSTALL=0
TEST=0
TEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dev)     DEV=1 ;;
        --install) INSTALL=1 ;;
        --test)    TEST=1 ;;
        --test-suite=*) TEST=1; TEST_ARGS+=("--suite=${arg#*=}") ;;
        --list-tests) TEST=1; TEST_ARGS+=(--list) ;;
    esac
done

if (( DEV )); then
    APP_NAME="Ferrule (Developer)"
    EXECUTABLE="FerruleDeveloper"
    APP_BUNDLE_ID="com.sreecharan.ferrule.dev"
    BUILD_VARIANT_FLAGS=(-D FERRULE_DEVELOPMENT)
    APP_OPTIMIZATION_FLAGS=(-Onone)
    BUILD_CONFIGURATION="debug"
else
    APP_NAME="Ferrule"
    EXECUTABLE="Ferrule"
    APP_BUNDLE_ID="com.sreecharan.ferrule"
    BUILD_VARIANT_FLAGS=()
    APP_OPTIMIZATION_FLAGS=(-O)
    BUILD_CONFIGURATION="release"
fi
FAN_HELPER_ID="$APP_BUNDLE_ID.fan-control"
# Now Playing is read through /usr/bin/perl loading this library; see
# Sources/NowPlayingAdapter. Staged under Contents/Frameworks, signed on its own.
NOW_PLAYING_ADAPTER_ID="$APP_BUNDLE_ID.now-playing"
NOW_PLAYING_ADAPTER="libFerruleNowPlaying.dylib"
TARGET="arm64-apple-macosx14.0"
ENTITLEMENTS="Resources/Ferrule.entitlements"
LEGACY_IDENTITY="Ferrule Signing"

developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Developer ID Application' \
        | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

# A find-identity listing also names certificates codesign then rejects (an
# expired one fails the build with errSecInternalComponent), and -v excludes
# every self-signed one; ask codesign itself with a throwaway copy of /bin/echo.
legacy_identity_installed() {
    local probe signed=1
    # A locked keychain still lists its identities but cannot sign with them,
    # and this one is locked after every reboot; unlock it before asking.
    security unlock-keychain -p ferrule-signing \
        "$HOME/Library/Keychains/ferrule-signing.keychain-db" 2>/dev/null || true
    probe="$(mktemp)"
    cp /bin/echo "$probe"
    /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$probe" \
        >/dev/null 2>&1 && signed=0
    rm -f "$probe"
    return $signed
}

# Any build that lands in /Applications needs a stable signature, not just the
# Developer one: macOS ties Accessibility and Screen Recording grants to the
# exact binary hash, so an ad-hoc rebuild orphans them while System Settings
# keeps showing them as granted, and no new prompt ever appears. A plain
# --install strands them under the released bundle id, on the app the user
# actually relies on. When no identity is installed, create the stable local one
# up front instead of falling through to ad-hoc — setup-signing.sh is free,
# offline and idempotent. Gating on the install rather than the variant keeps
# this off CI, where neither ci.yml nor release.yml passes --install.
if (( DEV || INSTALL )) && [[ -z "$(developer_id_identity)" ]] \
    && ! legacy_identity_installed; then
    echo "▸ No signing identity installed; creating the stable local one…"
    if ! ./Tools/setup-signing.sh; then
        echo "  ⚠ Tools/setup-signing.sh failed; signing ad-hoc instead." >&2
        echo "    Accessibility and Screen Recording grants will not survive rebuilds:" >&2
        echo "    System Settings will show them as granted while the app is not trusted." >&2
        echo "    After fixing the identity, clear the stale grant once with:" >&2
        echo "      tccutil reset Accessibility $APP_BUNDLE_ID" >&2
    fi
fi

codesign_with_timestamp_retry() {
    local attempt
    for attempt in 1 2 3; do
        if /usr/bin/codesign "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "  Developer ID signing failed; retrying ($((attempt + 1))/3)"
            sleep "$attempt"
        fi
    done
    return 1
}

write_swift_output_file_map() {
    local output_file="$1"
    local object_dir="$2"
    shift 2
    local source artifact

    {
        print -r -- "{"
        print -r -- "  \"\": {"
        print -r -- "    \"swift-dependencies\": \"$object_dir/master.swiftdeps\""
        print -r -- "  }"
        for source in "$@"; do
            artifact="${source//\//__}"
            artifact="${artifact%.swift}"
            print -r -- ","
            print -r -- "  \"$source\": {"
            print -r -- "    \"object\": \"$object_dir/$artifact.o\","
            print -r -- "    \"swift-dependencies\": \"$object_dir/$artifact.swiftdeps\""
            print -r -- "  }"
        done
        print -r -- "}"
    } > "$output_file"
}

finalize_installed_bundle_after_child() {
    local bundle="$1"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
    local devid
    devid="$(developer_id_identity)"

    echo "▸ Finalizing installed signature…"
    sleep 3
    if [[ -n "$devid" ]]; then
        [[ -f "$helper" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$FAN_HELPER_ID" --sign "$devid" "$helper"
        [[ -f "$adapter" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$devid" "$adapter"
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$devid" "$bundle"
    elif legacy_identity_installed; then
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign "$LEGACY_IDENTITY" "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$LEGACY_IDENTITY" "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$bundle"
    else
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign - "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign - "$bundle"
    fi
    [[ -f "$helper" ]] && /usr/bin/codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && /usr/bin/codesign --verify --strict "$adapter"
    /usr/bin/codesign --verify --deep --strict "$bundle"
    echo "✓ Signature ready: $bundle"
}

if (( INSTALL && ! TEST )) && [[ "${FERRULE_INSTALL_CHILD:-0}" != "1" ]]; then
    FERRULE_INSTALL_CHILD=1 "$0" "$@"
    child_status=$?
    if (( child_status != 0 )); then
        exit "$child_status"
    fi
    finalize_installed_bundle_after_child "/Applications/$APP_NAME.app"
    exit 0
fi

# Prefer the macOS 26 SDK when present: the 27 SDK turns SwiftUI property wrappers
# into macros (SwiftUIMacros plugin) that the Command Line Tools cannot load yet.
PINNED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    SDK="$(xcrun --show-sdk-path)"
elif [[ -d "$PINNED_SDK" ]]; then
    SDK="$PINNED_SDK"
else
    SDK="$(xcrun --show-sdk-path)"
fi
SDK_COMPAT_FLAGS=()
VM_STATISTICS_COMPAT_FLAGS=(-I Sources/VMStatisticsCompat)
HID_EVENT_SYSTEM_FLAGS=(-I Sources/HIDEventSystem)
if [[ "$SDK" == "$PINNED_SDK" ]]; then
    # Swift 6.4 can read the SDK 26 interfaces when given their compiler version.
    SDK_COMPAT_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
fi

# The defaults migrations under test need a real UserDefaults suite, and every
# suite leaves an empty plist in ~/Library/Preferences. The tests already clear
# the domains, but cfprefsd writes the emptied file back out around the time the
# process that owned it exits, so only a caller that outlives the run can remove
# them. `PreferenceNamespaceTests` scans every compiled Swift test file against
# these namespaces, which keeps this sweep complete without a second list.
discard_test_preferences() {
    local preferences="${1:-$HOME/Library/Preferences}" name attempt
    local survivors=0 quiet_passes=0
    # cfprefsd can recreate an emptied domain after the first removal. Require
    # two quiet checks, but keep a hard limit so persistent failures still fail CI.
    for attempt in {1..10}; do
        for name in "ferrule.tests." "com.sreecharan.ferrule.tests."; do
            rm -f "$preferences"/$name*.plist(N)
        done
        rm -f "$preferences/metrics-tests.plist"
        sleep 0.2
        survivors=$(find "$preferences" -maxdepth 1 \
            \( -name "ferrule.tests.*.plist" -o -name "com.sreecharan.ferrule.tests.*.plist" \
               -o -name "metrics-tests.plist" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$survivors" == "0" ]]; then
            quiet_passes=$((quiet_passes + 1))
            if (( quiet_passes == 2 )); then return 0; fi
        else
            quiet_passes=0
        fi
    done
    echo "✗ test preferences did not settle in $preferences ($survivors remaining)" >&2
    return 1
}

# Standalone automated tests: pure contracts plus isolated disk, subprocess,
# keyboard-data and media fixtures. No application windows or device capture.
if (( TEST )); then
    python3 Tests/generate_sources.py
    TEST_OBJECT_DIR="build/objects/tests"
    mkdir -p "$TEST_OBJECT_DIR"
    TEST_SOURCES=(
        Sources/Ferrule/Services/Media/MediaSupport.swift
        Sources/Ferrule/Core/QuitProtectionSupport.swift
        Sources/Ferrule/Core/QuitProtectionStrings.swift
        Sources/Ferrule/Core/Defaults.swift
        Sources/Ferrule/Core/NotchStrings.swift
        Sources/Ferrule/Core/NotchTourStrings.swift
        Sources/Ferrule/Core/NotchEditorStrings.swift
        Sources/Ferrule/UI/Settings/NotchSettingsTabRow.swift
        Sources/Ferrule/Core/NotchActivityStrings.swift
        Sources/Ferrule/Services/Notch/NotchTimerSupport.swift
        Sources/Ferrule/Services/Notch/NotchTimerAlert.swift
        Sources/Ferrule/UI/Notch/NotchIslandAlert.swift
        Sources/Ferrule/Services/Notch/NotchAccessorySupport.swift
        Sources/Ferrule/Services/QuickTools/CameraPreviewSupport.swift
        Sources/Ferrule/Core/NotchMusicExtrasStrings.swift
        Sources/Ferrule/Core/NotchClipboardSizeStrings.swift
        Sources/Ferrule/Services/Notch/NotchLyricsSupport.swift
        Sources/Ferrule/Services/Notch/NotchQueueSupport.swift
        Sources/Ferrule/Services/Notch/NotchPreferredPlayer.swift
        Sources/Ferrule/Core/NotchFilesStrings.swift
        Sources/Ferrule/Core/NotchWatchStrings.swift
        Sources/Ferrule/Services/Notch/NotchWatchSupport.swift
        Sources/Ferrule/Core/NotchMascotStrings.swift
        Sources/Ferrule/Services/Notch/NotchMascotSupport.swift
        Sources/Ferrule/Services/CommandBar/CommandBarDropletMotion.swift
        Sources/Ferrule/Services/Notch/NotchFileToolsSupport.swift
        Sources/Ferrule/Services/Notch/NotchDownloadSupport.swift
        Sources/Ferrule/Services/Notch/NotchDownloadProgressObserver.swift
        Sources/Ferrule/Core/NotchCalendarStrings.swift
        Sources/Ferrule/Core/NotchNotificationStrings.swift
        Sources/Ferrule/Core/NotchGestureStrings.swift
        Sources/Ferrule/Core/NotchAgentStrings.swift
        Sources/Ferrule/Core/CodexAccountStrings.swift
        Sources/Ferrule/Services/Notch/NotchAgentSupport.swift
        Sources/Ferrule/Core/NotchLockScreenStrings.swift
        Sources/Ferrule/Services/Notch/NotchLockScreenSupport.swift
        Sources/Ferrule/Services/AgentUsage/AgentUsageModels.swift
        Sources/Ferrule/Services/AgentUsage/AgentPricing.swift
        Sources/Ferrule/Services/AgentUsage/AgentLogObject.swift
        Sources/Ferrule/Services/AgentUsage/AgentLogParser.swift
        Sources/Ferrule/Services/AgentUsage/Harness/AgentHarnessReader.swift
        Sources/Ferrule/Services/AgentUsage/Harness/ClaudeReader.swift
        Sources/Ferrule/Services/AgentUsage/Harness/CodexReader.swift
        Sources/Ferrule/Services/AgentUsage/Harness/OpenCodeReader.swift
        Sources/Ferrule/Services/AgentUsage/Harness/CopilotReader.swift
        Sources/Ferrule/Services/AgentUsage/AgentUsageSummary.swift
        Sources/Ferrule/Services/AgentUsage/AgentUsageStore.swift
        Sources/Ferrule/Services/AgentUsage/AgentUsageArchive.swift
        Sources/Ferrule/Services/AgentUsage/AgentClaudeAppUsage.swift
        Sources/Ferrule/Services/AgentUsage/AgentCLIConversation.swift
        Sources/Ferrule/Services/AgentUsage/AgentClaudeServer.swift
        Sources/Ferrule/Services/AgentUsage/AgentCodexServer.swift
        Sources/Ferrule/Services/AgentUsage/CodexAccountLimits.swift
        Sources/Ferrule/Services/AgentUsage/CodexProfileLimitsService.swift
        Sources/Ferrule/Services/AgentUsage/AgentOpenCodeReader.swift
        Sources/Ferrule/Services/Notch/NotchGestureSupport.swift
        Sources/Ferrule/Services/Notch/NotchSectionPaging.swift
        Sources/Ferrule/Services/Notch/NotchSliderEditing.swift
        Sources/Ferrule/Services/Notch/NotchNotificationSupport.swift
        Sources/Ferrule/Services/Notch/NotchNotificationReaderCore.swift
        Sources/Ferrule/Services/Notch/NotchCalendarSupport.swift
        Sources/Ferrule/Services/Notch/NotchKeepAwakeSupport.swift
        Sources/Ferrule/Services/Notch/NotchSupport.swift
        Sources/Ferrule/Services/Notch/NotchAudioLevelSupport.swift
        Sources/Ferrule/Services/Notch/NotchVolumeKeyGate.swift
        Sources/Ferrule/Services/Notch/NotchMusicSupport.swift
        Sources/Ferrule/UI/Notch/NotchDecorativeClock.swift
        Sources/Ferrule/Services/Notch/NotchBrowserArtworkSupport.swift
        Sources/Ferrule/UI/Notch/NotchEqualizerBars.swift
        Sources/Ferrule/UI/Notch/NotchScrollEdgeFade.swift
        Sources/Ferrule/UI/Notch/NotchAgentAnimationView.swift
        Sources/Ferrule/UI/WindowVisibilityReader.swift
        Sources/Ferrule/Services/Notch/NotchMusicAutomationSupport.swift
        Sources/Ferrule/Services/Notch/NotchMusicAutomation.swift
        Sources/Ferrule/Services/Notch/NotchPlaybackSource.swift
        Sources/Ferrule/Services/Notch/NotchPlaybackCommand.swift
        Sources/Ferrule/Services/Notch/NotchMusicCommandWriter.swift
        Sources/Ferrule/Core/FeatureCatalog.swift
        Sources/Ferrule/Core/FeaturePresets.swift
        Sources/Ferrule/Core/FeatureHubStrings.swift
        Sources/Ferrule/Core/ShortcutSettingsStrings.swift
        Sources/Ferrule/Core/SettingsBackupSupport.swift
        Sources/Ferrule/Core/BackupStrings.swift
        Sources/Ferrule/Core/SnippetStrings.swift
        Sources/Ferrule/Core/AlertSoundStrings.swift
        Sources/Ferrule/Core/BrightnessStrings.swift
        Sources/Ferrule/Core/MediaImageStrings.swift
        Sources/Ferrule/Core/QuickToggleStrings.swift
        Sources/Ferrule/Core/ScreenshotStrings.swift
        Sources/Ferrule/Core/RecentCaptureStrings.swift
        Sources/Ferrule/Core/RecorderStrings.swift
        Sources/Ferrule/Core/CameraPreviewStrings.swift
        Sources/Ferrule/Core/WallpaperStrings.swift
        Sources/Ferrule/Services/Wallpaper/WallpaperSupport.swift
        Sources/Ferrule/Core/ScratchpadStrings.swift
        Sources/Ferrule/Core/FinderRenameStrings.swift
        Sources/Ferrule/Core/CommandBarStrings.swift
        Sources/Ferrule/Core/RadialMenuStrings.swift
        Sources/Ferrule/Core/MenuBarAppearanceStrings.swift
        Sources/Ferrule/Core/AppAppearance.swift
        Sources/Ferrule/Core/AppearanceStrings.swift
        Sources/Ferrule/Core/GeneralSettingsStrings.swift
        Sources/Ferrule/Core/SettingsPageStrings.swift
        Sources/Ferrule/Core/BatteryTimeStrings.swift
        Sources/Ferrule/Core/CPUCoreStrings.swift
        Sources/Ferrule/Core/MonitorLayoutStrings.swift
        Sources/Ferrule/Core/KeepAwakeStrings.swift
        Sources/Ferrule/Core/BluetoothSleepStrings.swift
        Sources/Ferrule/Core/PermissionGuideStrings.swift
        Sources/Ferrule/Core/FanControlStrings.swift
        Sources/Ferrule/Core/ConnectedDevicesStrings.swift
        Sources/Ferrule/Services/FanControl/FanControlSupport.swift
        Sources/Ferrule/Services/FanControl/FanControlResumeSupport.swift
        Sources/Ferrule/Services/Snippets/TextSnippetSupport.swift
        Sources/Ferrule/Services/RadialMenu/RadialMenuSupport.swift
        Sources/Ferrule/Services/QuickTools/ScratchpadSupport.swift
        Sources/Ferrule/Services/QuickTools/ScratchpadStore.swift
        Sources/Ferrule/Services/KillProcess/KillProcessSupport.swift
        Sources/Ferrule/Services/Recorder/RecorderSupport.swift
        Sources/Ferrule/Services/Recorder/RecorderSampleTiming.swift
        Sources/Ferrule/Services/Recorder/RecorderWriter.swift
        Sources/Ferrule/Services/Recorder/RecorderCaptureEngine.swift
        Sources/Ferrule/Core/RecorderExportStrings.swift
        Sources/Ferrule/Services/Recorder/RecorderComposer.swift
        Sources/Ferrule/Services/Recorder/RecorderComposerPlan.swift
        Sources/Ferrule/Services/Recorder/RecorderCursorSprite.swift
        Sources/Ferrule/Services/Recorder/RecorderTextRenderer.swift
        Sources/Ferrule/Services/Recorder/RecorderImageRenderer.swift
        Sources/Ferrule/Services/Recorder/RecorderExporter.swift
        Sources/Ferrule/Services/Recorder/RecorderGIFClipboard.swift
        Sources/Ferrule/Services/Recorder/RecorderGIFWriter.swift
        Sources/Ferrule/Services/Recorder/RecorderGIFWorkspace.swift
        Sources/Ferrule/Services/Recorder/RecorderComposition.swift
        Sources/Ferrule/Services/PrivateFileStore.swift
        Sources/Ferrule/Services/Recorder/RecorderTakeStore.swift
        Sources/Ferrule/Services/Recorder/RecorderPresetImageStore.swift
        Sources/Ferrule/Services/Recorder/RecorderMotion.swift
        Sources/Ferrule/Services/Recorder/RecorderPointerTrack.swift
        Sources/Ferrule/Services/Recorder/RecorderTypingTrack.swift
        Sources/Ferrule/Services/Recorder/RecorderTimeline.swift
        Sources/Ferrule/Services/Recorder/RecorderTextOverlay.swift
        Sources/Ferrule/Services/Recorder/RecorderImageOverlay.swift
        Sources/Ferrule/Services/Recorder/RecorderBlurRegion.swift
        Sources/Ferrule/Services/Recorder/RecorderEditDocument.swift
        Sources/Ferrule/Core/AppInfo.swift
        Sources/Ferrule/Core/GlobalShortcut.swift
        Sources/Ferrule/Core/SymbolicHotKeys.swift
        Sources/Ferrule/Services/SystemShortcutTakeoverSupport.swift
        Sources/Ferrule/Core/Localization.swift
        Sources/Ferrule/Core/Localizations/Strings+*.swift
        Sources/Ferrule/Core/FeatureStrings.swift
        Sources/Ferrule/Core/KillProcessStrings.swift
        Sources/Ferrule/Core/PortManagerStrings.swift
        Sources/Ferrule/Core/WhatsAppDownloadStrings.swift
        Sources/Ferrule/Core/WhatsAppOrganizerStrings.swift
        Sources/Ferrule/Core/ReleaseNotes.swift
        Sources/Ferrule/Core/ReleaseDigest.swift
        Sources/Ferrule/Core/ReleaseChangeAliases.swift
        Sources/Ferrule/Core/WhatsNewStrings.swift
        Sources/Ferrule/Core/URLCleaning.swift
        Sources/Ferrule/Services/GeneralPasteboardAccess.swift
        Sources/Ferrule/Services/Clipboard/ClipboardHistoryWrite.swift
        Sources/Ferrule/Services/Audio/AirPlayRouteManager.swift
        Sources/Ferrule/Services/Audio/MixerRoutingSupport.swift
        Sources/Ferrule/Services/Audio/MusicLaunchSupport.swift
        Sources/Ferrule/Services/Bluetooth/BluetoothSleepSupport.swift
        Sources/Ferrule/UI/MenuPanel/MixerPercentNativeTextField.swift
        Sources/Ferrule/UI/MenuPanel/MixerAppDragSource.swift
        Sources/Ferrule/Services/Audio/BoostLimiter.swift
        Sources/Ferrule/Services/Audio/MixerRender.swift
        Sources/Ferrule/Services/Audio/PreciseVolumeRollerSupport.swift
        Sources/Ferrule/Services/DockPreview/DockPreviewSupport.swift
        Sources/Ferrule/Services/DockPreview/DockAutohideHold.swift
        Sources/Ferrule/Services/SpacesOrder/SpacesOrderHold.swift
        Sources/Ferrule/Services/Homebrew/HomebrewSupport.swift
        Sources/Ferrule/Services/Homebrew/HomebrewEnvironment.swift
        Sources/Ferrule/Services/AppUpdates/AppUpdatesSupport.swift
        Sources/Ferrule/Services/AppUpdates/AppUpdateFeedSupport.swift
        Sources/Ferrule/Core/AppUpdateStrings.swift
        Sources/Ferrule/Core/DiskImageInstallerStrings.swift
        Sources/Ferrule/Services/DiskImageInstaller/DiskImageInstallerSupport.swift
        Sources/Ferrule/UI/NonModalAlert.swift
        Sources/Ferrule/Services/Clipboard/ClipboardHistorySupport.swift
        Sources/Ferrule/Core/ColorValue.swift
        Sources/Ferrule/Services/Clipboard/ClipboardAutoClearSupport.swift
        Sources/Ferrule/Services/AutoQuit/AutoQuitSupport.swift
        Sources/Ferrule/Services/Shelf/ShelfSupport.swift
        Sources/Ferrule/Services/Shelf/ShelfFilePromiseTransfer.swift
        Sources/Ferrule/Core/ShelfPromiseDeliveryStrings.swift
        Sources/Ferrule/Services/Finder/FinderRenameSupport.swift
        Sources/Ferrule/Services/Update/UpdateInstallerSupport.swift
        Sources/Ferrule/Services/Update/UpdateServiceSupport.swift
        Sources/Ferrule/Services/InstalledApps.swift
        Sources/Ferrule/Services/LaunchAtLoginSupport.swift
        Sources/Ferrule/UI/Settings/SettingsSearchSupport.swift
        Sources/Ferrule/UI/Settings/SettingsSidebarSupport.swift
        Sources/Ferrule/UI/Settings/FeatureVisibilitySupport.swift
        Sources/Ferrule/UI/Onboarding/WhatsNewSupport.swift
        Sources/Ferrule/UI/Settings/SettingsWindow.swift
        Sources/Ferrule/Core/SettingsNavigationStrings.swift
        Sources/Ferrule/App/MenuBarSpacingSupport.swift
        Sources/Ferrule/App/MenuBarAllowanceSupport.swift
        Sources/Ferrule/App/ReopenRequestSupport.swift
        Sources/Ferrule/App/StatusItemAnchorSupport.swift
        Sources/Ferrule/Services/DockClick/DockClickSupport.swift
        Sources/Ferrule/Services/Finder/CutPasteProgressSupport.swift
        Sources/Ferrule/Services/Finder/CutPastePrivilegeSupport.swift
        Sources/Ferrule/Services/Finder/FinderPasteImageSupport.swift
        Sources/Ferrule/Services/MiddleClick/MiddleClickSupport.swift
        Sources/Ferrule/Services/MouseNavigation/MouseNavigationSupport.swift
        Sources/Ferrule/Services/MouseNavigation/MouseNavigationKeys.swift
        Sources/Ferrule/Services/MouseButtons/MouseButtonShortcutSupport.swift
        Sources/Ferrule/Services/MouseButtons/MouseSpacesGestureSupport.swift
        Sources/Ferrule/Services/MouseClickDebounce/MouseClickDebounceSupport.swift
        Sources/Ferrule/Services/MouseExceptions/MouseAppExceptionSupport.swift
        Sources/Ferrule/Services/MouseExceptions/MouseAppExceptions.swift
        Sources/Ferrule/Services/WindowServerSupport.swift
        Sources/Ferrule/Services/WindowMaximizerSupport.swift
        Sources/Ferrule/Core/MouseButtonStrings.swift
        Sources/Ferrule/Core/MouseClickDebounceStrings.swift
        Sources/Ferrule/Core/MouseExceptionStrings.swift
        Sources/Ferrule/Core/ClipboardIgnoredAppsStrings.swift
        Sources/Ferrule/Core/ClipboardRetentionStrings.swift
        Sources/Ferrule/Core/WindowLayoutIgnoredAppsStrings.swift
        Sources/Ferrule/Services/WindowLayout/WindowLayoutIgnoredApps.swift
        Sources/Ferrule/Core/WindowPreviewExclusionStrings.swift
        Sources/Ferrule/Core/WindowMaximizerExclusionStrings.swift
        Sources/Ferrule/Core/DiskExclusionStrings.swift
        Sources/Ferrule/Core/SwitcherAppRulesStrings.swift
        Sources/Ferrule/Services/QuickTools/QuickToolsSupport.swift
        Sources/Ferrule/Services/CommandBar/CommandBarSupport.swift
        Sources/Ferrule/Services/CommandBar/CommandBarPreferences.swift
        Sources/Ferrule/Services/CommandBar/CommandBarMath.swift
        Sources/Ferrule/Services/CommandBar/CommandBarUnits.swift
        Sources/Ferrule/Services/CommandBar/CommandBarColors.swift
        Sources/Ferrule/Services/CommandBar/CommandBarEmoji.swift
        Sources/Ferrule/Services/CommandBar/CommandBarLinks.swift
        Sources/Ferrule/Services/CommandBar/CommandBarDates.swift
        Sources/Ferrule/Services/CommandBar/CommandBarRowShortcuts.swift
        Sources/Ferrule/Services/CommandBar/CommandBarSystemSettingsSupport.swift
        Sources/Ferrule/Services/CommandBar/CommandBarFileSearchSupport.swift
        Sources/Ferrule/Services/CommandBar/CommandBarQueryMemory.swift
        Sources/Ferrule/Services/SpotlightNamesSupport.swift
        Sources/Ferrule/Services/QuickTools/MicMuteSupport.swift
        Sources/Ferrule/Services/QuickTools/QuickTogglesSupport.swift
        Sources/Ferrule/Services/QuickTools/ScreenshotCapturePolicy.swift
        Sources/Ferrule/Services/QuickTools/ScreenshotSupport.swift
        Sources/Ferrule/Services/QuickTools/ScreenshotCanvasSupport.swift
        Sources/Ferrule/UI/Settings/ScreenCaptureToolPicker.swift
        Sources/Ferrule/UI/Settings/MonitorToken.swift
        Sources/Ferrule/Services/QuickTools/ScreenshotRenderer.swift
        Sources/Ferrule/Services/QuickTools/ScreenshotImageLayerRendering.swift
        Sources/Ferrule/Services/QuickTools/RecentCaptureStore.swift
        Sources/Ferrule/Services/QuickTools/WindowActivationPolicy.swift
        Sources/Ferrule/Services/KeyboardDebounce/KeyboardDebounceSupport.swift
        Sources/Ferrule/Services/SuperKey/SuperKeySupport.swift
        Sources/Ferrule/Services/SuperKey/SuperKeyMappingGuard.swift
        Sources/Ferrule/Core/SuperKeyStrings.swift
        Sources/Ferrule/Core/InputSourceSelection.swift
        Sources/Ferrule/Services/SessionActivity.swift
        Sources/Ferrule/Services/SessionActivitySupport.swift
        Sources/Ferrule/Services/EventTimestamp.swift
        Sources/Ferrule/Services/OwnKeyEvent.swift
        Sources/Ferrule/Services/ScrollWheelSupport.swift
        Sources/Ferrule/Services/HorizontalWheelScrolling.swift
        Sources/Ferrule/Services/SmoothScrollSupport.swift
        Sources/Ferrule/Services/MouseAcceleration/MouseAccelerationSupport.swift
        Sources/Ferrule/Services/FocusFollowsMouse/FocusFollowsMouseSupport.swift
        Sources/Ferrule/Services/AssistiveKeyboard.swift
        Sources/Ferrule/Services/Switcher/SwitcherModels.swift
        Sources/Ferrule/Services/Switcher/WindowServerCaptureQueue.swift
        Sources/Ferrule/Services/Switcher/SwitcherSupport.swift
        Sources/Ferrule/Services/Switcher/SpaceHopSupport.swift
        Sources/Ferrule/Services/Switcher/WindowUseOrder.swift
        Sources/Ferrule/Services/Metrics/MetricFormat.swift
        Sources/Ferrule/Services/Metrics/VMStatisticsDecoder.swift
        Sources/Ferrule/Services/KeepAwakeAutomationSupport.swift
        Sources/Ferrule/Services/SudoersSupport.swift
        Sources/Ferrule/Services/Metrics/BatteryTimeSupport.swift
        Sources/Ferrule/Services/Metrics/BatteryPowerSupport.swift
        Sources/Ferrule/Services/BoundedProcessRunner.swift
        Sources/Ferrule/Services/DetachedProcess.swift
        Sources/Ferrule/Services/ShellSupport.swift
        Sources/Ferrule/Services/PortManager/PortManagerSupport.swift
        Sources/Ferrule/Services/Metrics/NetworkProcessSupport.swift
        Sources/Ferrule/Services/Metrics/NetworkSampler.swift
        Sources/Ferrule/Services/Metrics/NetworkAddressService.swift
        Sources/Ferrule/Services/Metrics/SpeedTest.swift
        Sources/Ferrule/Services/Metrics/PeripheralBatterySampler.swift
        Sources/Ferrule/Services/Metrics/PeripheralBatterySupport.swift
        Sources/Ferrule/Services/Metrics/DiskSupport.swift
        Sources/Ferrule/Services/Metrics/MonitorSamplingPolicy.swift
        Sources/Ferrule/Services/Metrics/USBDeviceSampler.swift
        Sources/Ferrule/Services/Metrics/CPUCoreSampler.swift
        Sources/Ferrule/Services/Metrics/MaxCapacityProbe.swift
        Sources/Ferrule/Services/Metrics/TemperatureSensorSelector.swift
        Sources/Ferrule/Services/Metrics/SustainedAlertGate.swift
        Sources/Ferrule/Services/WindowLayout/WindowLayoutSupport.swift
        Sources/Ferrule/Services/WindowLayout/WindowGestureSupport.swift
        Sources/Ferrule/Core/WindowDirectionalStrings.swift
        Sources/Ferrule/Core/PointerDisplayStrings.swift
        Sources/Ferrule/Core/GraphScaleStrings.swift
        Sources/Ferrule/Core/NotchLowBatteryStrings.swift
        Sources/Ferrule/Services/CleaningMode/CleaningUnlockCounter.swift
        Sources/Ferrule/Services/CleaningMode/CleaningMouseReleaseGate.swift
        Sources/Ferrule/Services/Display/ExtraBrightnessSupport.swift
        Sources/Ferrule/Services/Display/BrightnessSupport.swift
        Sources/Ferrule/Services/Display/LidDimmingSupport.swift
        Sources/Ferrule/Services/Cleaner/CleanerSupport.swift
        Sources/Ferrule/Services/Cleaner/CleanerPolicy.swift
        Sources/Ferrule/Services/Cleaner/CleanerSchedule.swift
        Sources/Ferrule/Services/Uninstall/UninstallerSupport.swift
        Sources/Ferrule/Services/ManagedDownloads/WhatsAppDownloadSupport.swift
        Sources/Ferrule/Core/SecureInputSupport.swift
        Sources/Ferrule/Services/Convert/RecastSupport.swift
        Sources/Ferrule/Core/ConvertStrings.swift
        Tests/*.swift
        build/generated-tests/*.swift
    )
    TEST_OUTPUT_FILE_MAP="$TEST_OBJECT_DIR/output-file-map.json"
    write_swift_output_file_map "$TEST_OUTPUT_FILE_MAP" "$TEST_OBJECT_DIR" "${TEST_SOURCES[@]}"
    echo "▸ Building & running tests against $(basename "$SDK")…"
    swiftc -Onone -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
        -module-name FerruleTests -output-file-map "$TEST_OUTPUT_FILE_MAP" \
        -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" \
        "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${TEST_SOURCES[@]}" -o build/metrics-tests
    test_status=0
    ./build/metrics-tests "${TEST_ARGS[@]}" || test_status=$?
    if (( ${#TEST_ARGS} == 0 )); then
        ./Tests/PreferenceCleanupTests.sh || test_status=1
        ./Tests/UninstallSpacesTests.sh || test_status=1
        ./Tests/DeveloperInstallIsolationTests.sh || test_status=1
    fi
    discard_test_preferences || test_status=1
    exit $test_status
fi

echo "▸ Compiling ($BUILD_CONFIGURATION) against $(basename "$SDK")…"
APP_SOURCES=(Sources/Ferrule/**/*.swift)
if (( ! DEV )); then
    # A release starts from an empty build directory, so nothing an earlier
    # build left behind (an old icon catalog, a staged bundle) can reach it.
    # Only the compiler's incremental records stay: they rebuild whatever
    # changed since, and a fresh checkout has none.
    find build -mindepth 1 -maxdepth 1 ! -name objects -exec rm -rf {} + 2>/dev/null || true
fi
APP_OBJECT_DIR="build/objects/$EXECUTABLE"
mkdir -p build "$APP_OBJECT_DIR"
APP_OUTPUT_FILE_MAP="$APP_OBJECT_DIR/output-file-map.json"
write_swift_output_file_map "$APP_OUTPUT_FILE_MAP" "$APP_OBJECT_DIR" "${APP_SOURCES[@]}"
# Without -j the driver compiles one file at a time, and without batch mode
# each file's compiler parses the whole module again: a clean release took a
# quarter of an hour. Batches share that work and run on every core, and the
# optimization stays per file, as before.
swiftc "${APP_OPTIMIZATION_FLAGS[@]}" -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
    -output-file-map "$APP_OUTPUT_FILE_MAP" \
    -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${HID_EVENT_SYSTEM_FLAGS[@]}" \
    "${BUILD_VARIANT_FLAGS[@]}" \
    "${APP_SOURCES[@]}" -o "build/$EXECUTABLE"

echo "▸ Compiling protected fan helper…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${BUILD_VARIANT_FLAGS[@]}" \
    Sources/Ferrule/Services/FanControl/FanControlSupport.swift \
    Sources/Ferrule/Services/FanControl/FanControlXPC.swift \
    Sources/Ferrule/Services/SystemMonitor/SMCClient.swift \
    Sources/Ferrule/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Ferrule/Services/FanControl/FanControlHardware.swift \
    Sources/FanControlHelper/main.swift \
    -o "build/$FAN_HELPER_ID"
"build/$FAN_HELPER_ID" --selftest

echo "▸ Compiling Now Playing adapter…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" -emit-library \
    -module-name FerruleNowPlaying \
    Sources/NowPlayingAdapter/NowPlayingAdapter.swift \
    Sources/NowPlayingAdapter/NowPlayingQueue.swift \
    Sources/NowPlayingAdapter/NowPlayingSelection.swift \
    Sources/Ferrule/Services/Notch/NotchPlaybackSource.swift \
    Sources/Ferrule/Services/Notch/NotchPlaybackCommand.swift \
    -o "build/$NOW_PLAYING_ADAPTER"

echo "▸ Generating app icon…"
swift Tools/MakeIcon.swift build/AppIcon.iconset
xattr -c -r build/AppIcon.iconset build/AppIcon.icns build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png 2>/dev/null || true
ACTOOL_BIN="$(xcrun --find actool 2>/dev/null || true)"
ICON_TMP="$(mktemp -d)"
ADAPTIVE_SKIP=""
if [[ -z "$ACTOOL_BIN" ]]; then
    ADAPTIVE_SKIP="actool not found (adaptive icons need Xcode 26+)"
else
    echo "▸ Compiling adaptive icon catalog…"
    # actool crashes on File Provider-synced paths, so compile a local copy.
    ditto "Resources/Brand/AppIcon.icon" "$ICON_TMP/AppIcon.icon"
    ditto "Resources/Brand/Accent.xcassets" "$ICON_TMP/Accent.xcassets"
    # Xcode 27 beta actool requires the --compile target directory to already exist.
    mkdir -p "$ICON_TMP/catalog"
    if "$ACTOOL_BIN" "$ICON_TMP/AppIcon.icon" "$ICON_TMP/Accent.xcassets" \
            --compile "$ICON_TMP/catalog" \
            --app-icon AppIcon \
            --accent-color AccentColor \
            --platform macosx \
            --target-device mac \
            --minimum-deployment-target 14.0 \
            --enable-on-demand-resources NO \
            --output-partial-info-plist "$ICON_TMP/partial-info.plist" \
            >"$ICON_TMP/actool.log" 2>&1 && [[ -s "$ICON_TMP/catalog/Assets.car" ]]; then
        mv "$ICON_TMP/catalog/Assets.car" build/Assets.car
    else
        ADAPTIVE_SKIP="actool could not compile the catalog"
    fi
fi
if [[ -n "$ADAPTIVE_SKIP" ]]; then
    cp "$ICON_TMP/actool.log" build/actool-failure.log 2>/dev/null || true
    echo "  adaptive icon skipped: $ADAPTIVE_SKIP (Dock falls back to AppIcon.icns)"
fi
echo "▸ Assembling and signing bundle…"
STAGE_TMP="$(mktemp -d)"
STAGE="$STAGE_TMP/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" \
    "$STAGE/Contents/Library/LaunchDaemons" "$STAGE/Contents/Library/LaunchServices"
cp "build/$EXECUTABLE" "$STAGE/Contents/MacOS/$EXECUTABLE"
cp "build/$FAN_HELPER_ID" "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID"
mkdir -p "$STAGE/Contents/Frameworks"
cp "build/$NOW_PLAYING_ADAPTER" "$STAGE/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
cp Resources/now-playing.pl "$STAGE/Contents/Resources/now-playing.pl"
cp Resources/agent-prices.json "$STAGE/Contents/Resources/agent-prices.json"
cp Resources/com.sreecharan.ferrule.fan-control.plist \
    "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
cp CHANGELOG.md "$STAGE/Contents/Resources/CHANGELOG.md"
for lproj in Resources/*.lproj(N); do
    cp -R "$lproj" "$STAGE/Contents/Resources/"
done
if (( DEV )); then
    # A distinct identity so the Developer build installs and runs next to the
    # official app, with its own permissions, preferences and login item.
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE" "$STAGE/Contents/Info.plist"
    FAN_PLIST="$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
    /usr/libexec/PlistBuddy -c "Set :Label $FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Set :BundleProgram Contents/Library/LaunchServices/$FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Delete :MachServices:com.sreecharan.ferrule.fan-control" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Add :MachServices:$FAN_HELPER_ID bool true" "$FAN_PLIST"
    # Stamp the source commit + build time so the running dev app shows (in About)
    # exactly which code it was compiled from. Lets you verify it matches HEAD before
    # testing, instead of unknowingly running a stale build. Dev-only; never shipped.
    SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && SHA="$SHA-dirty"
    /usr/libexec/PlistBuddy -c "Add :FerruleBuildCommit string '$SHA · $(date '+%Y-%m-%d %H:%M')'" "$STAGE/Contents/Info.plist"
    echo "  stamped dev build: $SHA"
fi
FAN_HELPER_VERSION="$(
    export LC_ALL=C
    /usr/bin/shasum -a 256 \
        "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID" \
        "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist" \
        | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
        | /usr/bin/awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c "Add :FerruleFanControlHelperVersion string '$FAN_HELPER_VERSION'" \
    "$STAGE/Contents/Info.plist"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
cp build/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cp build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png "$STAGE/Contents/Resources/"
if [[ -f build/Assets.car ]]; then
    cp build/Assets.car "$STAGE/Contents/Resources/Assets.car"
fi
if [[ -d Resources/Gifs ]]; then
    mkdir -p "$STAGE/Contents/Resources/Gifs"
    cp Resources/Gifs/*.gif "$STAGE/Contents/Resources/Gifs/"
fi
if ! cmp -s Resources/Gifs/highlights-notch.gif "$STAGE/Contents/Resources/Gifs/highlights-notch.gif"; then
    echo "Dynamic Island tour GIF is missing or differs from the bundled copy" >&2
    exit 1
fi
if [[ -d Resources/Images ]]; then
    mkdir -p "$STAGE/Contents/Resources/Images"
    cp Resources/Images/* "$STAGE/Contents/Resources/Images/"
fi
# Convert's engine: Recast's converter, built from the source in Recast/ and
# carried inside the app. SKIP_RECAST=1 builds without it (Convert then says
# its converter is missing).
if [[ "${SKIP_RECAST:-0}" != "1" ]]; then
    echo "▸ Building Recast's converter…"
    Tools/build-recast.sh build/recast
    Tools/embed-recast.sh build/recast "$STAGE"
else
    echo "  Recast not embedded (SKIP_RECAST=1)"
fi
xattr -c -r "$STAGE" 2>/dev/null || true

# Signing, in order of preference:
#   1. Developer ID Application — the real, Apple-issued identity used for
#      notarized releases. Signed with the hardened runtime (required for
#      notarization), the app's entitlements and a secure timestamp. Gives a
#      stable, team-based designated requirement, so permissions persist across
#      updates AND Gatekeeper shows no "unverified developer" warning.
#   2. "Ferrule Signing" — the legacy stable self-signed identity, kept
#      as a fallback so contributors without a Developer ID still get a constant
#      designated requirement across their local builds.
#   3. Ad-hoc — fresh clone with no identity at all.
DEVID="$(developer_id_identity)"
codesign_app() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --sign - "$target"
    fi
}

codesign_fan_helper() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$FAN_HELPER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" --sign - "$target"
    fi
}

codesign_now_playing_adapter() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$target"
    fi
}

# Every executable and library inside the embedded Recast, deepest first, with
# the app's identity and the JIT entitlement .NET needs.
codesign_recast() {
    local root="$1/Contents/Resources/Recast"
    [[ -d "$root" ]] || return 0
    local file
    find "$root" -type f | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | while IFS= read -r file; do
        /usr/bin/file -b "$file" | grep -q '^Mach-O' || continue
        if [[ -n "$DEVID" ]]; then
            codesign_with_timestamp_retry --force --options runtime --timestamp \
                --entitlements Resources/Recast.entitlements --sign "$DEVID" "$file"
        elif legacy_identity_installed; then
            codesign --force --entitlements Resources/Recast.entitlements --sign "$LEGACY_IDENTITY" "$file"
        else
            codesign --force --entitlements Resources/Recast.entitlements --sign - "$file"
        fi
    done
}

sign_bundle() {
    local bundle="$1"
    local executable="$bundle/Contents/MacOS/$EXECUTABLE"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"

    if [[ -n "$DEVID" ]]; then
        echo "  signing with Developer ID (hardened runtime): $DEVID"
    elif legacy_identity_installed; then
        echo "  signing with legacy self-signed identity: $LEGACY_IDENTITY"
    else
        echo "  signing ad-hoc (no identity installed — run Tools/setup-signing.sh)"
    fi
    [[ -f "$helper" ]] && codesign_fan_helper "$helper"
    [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
    codesign_recast "$bundle"
    codesign_app "$bundle"

    # If local filesystem metadata invalidates the first signature, sign once
    # more. The installed Developer bundle is signed again after the final copy.
    if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
        echo "  re-signing after filesystem metadata settled"
        xattr -c -r "$bundle" 2>/dev/null || true
        [[ -f "$helper" ]] && codesign_fan_helper "$helper"
        [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
        codesign_recast "$bundle"
        codesign_app "$bundle"
    fi
    [[ -f "$executable" ]] && codesign --verify --strict "$executable"
    [[ -f "$helper" ]] && codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && codesign --verify --strict "$adapter"
    codesign --verify --deep --strict "$bundle"
}

sign_installed_bundle() {
    local bundle="$1"
    wait_for_install_metadata "$bundle"
    sign_bundle "$bundle"
}

sign_bundle "$STAGE"

process_is_running() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pgrep -f "/Contents/MacOS/$proc" >/dev/null 2>&1
    else
        pgrep -x "$proc" >/dev/null 2>&1
    fi
}

stop_process() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pkill -f "/Contents/MacOS/$proc" 2>/dev/null || true
    else
        pkill -x "$proc" 2>/dev/null || true
    fi
    for _ in {1..50}; do
        if ! process_is_running "$proc"; then
            return 0
        fi
        sleep 0.1
    done
    echo "✗ $proc is still running — quit it and retry" >&2
    return 1
}

wait_for_install_metadata() {
    local bundle="$1"
    local missing
    for _ in {1..50}; do
        missing=0
        while IFS= read -r file; do
            if ! xattr -p com.apple.provenance "$file" >/dev/null 2>&1; then
                missing=1
                break
            fi
        done < <(find "$bundle/Contents" -type f ! -path "*/_CodeSignature/*")
        if (( missing == 0 )); then
            return 0
        fi
        sleep 0.1
    done
}

# Installed development builds only need the copy in /Applications. Retaining
# another app in each checkout pollutes application search with stale builds.
if (( DEV )); then
    for old_bundle in "build/stage/$APP_NAME.app" "build/stage.noindex/$APP_NAME.app"; do
        if [[ -d "$old_bundle" ]]; then
            /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
                -u "$PWD/$old_bundle" >/dev/null 2>&1 || true
            rm -rf "$old_bundle"
        fi
    done
fi

if (( !DEV || !INSTALL )); then
    STAGE_DIRECTORY="build/stage"
    (( DEV )) && STAGE_DIRECTORY="build/stage.noindex"
    mkdir -p "$STAGE_DIRECTORY"
    BUILD_STAGE="$STAGE_DIRECTORY/$APP_NAME.app"
    rm -rf "$BUILD_STAGE"
    ditto --noextattr --noqtn "$STAGE" "$BUILD_STAGE"
    xattr -c -r "$BUILD_STAGE" 2>/dev/null || true
    if ! codesign --verify --deep --strict "$BUILD_STAGE" >/dev/null 2>&1; then
        if xattr -lr "$BUILD_STAGE" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork|provenance|fileprovider)'; then
            echo "  staging copy has local filesystem metadata; temp bundle was verified"
        else
            codesign --verify --deep --strict "$BUILD_STAGE"
        fi
    fi
    echo "✓ Bundle ready: $BUILD_STAGE"
fi

if (( INSTALL )); then
    echo "▸ Installing into /Applications…"
    stop_process "$EXECUTABLE"
    INSTALL_DEST="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --noqtn "$STAGE" "$INSTALL_DEST"
    sign_installed_bundle "$INSTALL_DEST"
    echo "✓ Installed: $INSTALL_DEST"
fi
