#!/bin/bash

# MouthKeys release: a Developer ID signed, notarized, stapled app in a DMG.
#
# Usage:
#   scripts/release.sh                 # build, then package (same as ./build.sh dist)
#   scripts/release.sh build           # Release build only, signed to run locally (no keychain)
#   scripts/release.sh package [APP]   # sign, notarize, staple, DMG, verify an existing build
#   scripts/release.sh verify [APP] [DMG]
#
#   scripts/release.sh ship --notes FILE   # the whole release from the maintainer's Mac:
#                                          # build on the build host, package here, draft the
#                                          # GitHub release, install it here, ask, then publish
#   scripts/release.sh remote-build        # Release build of HEAD on the build host, copied back
#   scripts/release.sh install [APP]       # put a Developer ID app in /Applications: backup,
#                                          # rollback script, swap, hotkey check
#   scripts/release.sh publish [VERSION]   # publish the draft, check the download's sha256
#
# The two halves can run on different Macs: `build` needs only Xcode 26 and no
# signing identity, so a build host can make the app; `package` needs the
# Developer ID identity and the notary profile in the login keychain.
#
# Environment:
#   MOUTHKEYS_NOTARY_PROFILE   notarytool keychain profile (default: mouthkeys-notary)
#   MOUTHKEYS_SIGN_IDENTITY    codesign identity (default: the one Developer ID Application
#                                identity in the keychain, of MOUTHKEYS_DEVELOPMENT_TEAM if set)
#   MOUTHKEYS_DEVELOPMENT_TEAM Team ID that picks among several Developer ID identities
#   MOUTHKEYS_SKIP_NOTARIZE=1  sign and package without notarizing (signing check only;
#                                the result will not pass Gatekeeper on another Mac)
#   MOUTHKEYS_DIST_DIR         output folder (default: <repo>/dist)
#   FLUIDVOICE_DERIVED_DATA_PATH DerivedData folder (default: <repo>/DerivedData)
#   MOUTHKEYS_BUILD_HOST       ssh host for ship/remote-build (default: atlas; "local" builds here)
#   MOUTHKEYS_SHIP_DIR         ship's work folder (default: ~/Backups/mouthkeys-release-<version>)
#
# Per-machine settings (a notary profile under another name, a build host) can live in
# scripts/release.local.sh, which is git-ignored and sourced first when present.
#
# Never launch the built app. It is com.stage11.mouthkeys, the installed app's
# identity, and would write into the installed app's settings and data (CLAUDE.md).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
[ -f "${PROJECT_DIR}/scripts/release.local.sh" ] && . "${PROJECT_DIR}/scripts/release.local.sh"
DERIVED_DATA_PATH="${FLUIDVOICE_DERIVED_DATA_PATH:-${PROJECT_DIR}/DerivedData}"
DIST_DIR="${MOUTHKEYS_DIST_DIR:-${PROJECT_DIR}/dist}"
NOTARY_PROFILE="${MOUTHKEYS_NOTARY_PROFILE:-mouthkeys-notary}"
TEAM="${MOUTHKEYS_DEVELOPMENT_TEAM:-${FLUIDVOICE_DEVELOPMENT_TEAM:-}}"
SKIP_NOTARIZE="${MOUTHKEYS_SKIP_NOTARIZE:-0}"
BUILT_APP="${DERIVED_DATA_PATH}/Build/Products/Release/MouthKeys.app"
APP_NAME="MouthKeys.app"
VOLUME_NAME="MouthKeys"

IDENTITY=""

die() {
    printf >&2 '\nrelease: %s\n' "$1"
    shift
    local line
    for line in "$@"; do printf >&2 '  %s\n' "${line}"; done
    exit 1
}

step() { printf '\n==> %s\n' "$1"; }

# ---------------------------------------------------------------- preflight

resolve_identity() {
    if [ -n "${MOUTHKEYS_SIGN_IDENTITY:-}" ]; then
        IDENTITY="${MOUTHKEYS_SIGN_IDENTITY}"
    else
        local -a found=()
        local line
        while IFS= read -r line; do
            [ -n "${line}" ] && found+=("${line}")
        done < <(security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
            | { if [ -n "${TEAM}" ]; then grep -F "(${TEAM})" || true; else cat; fi; } \
            | sort -u)
        if [ "${#found[@]}" -eq 0 ]; then
            die "no Developer ID Application identity${TEAM:+ for team ${TEAM}} in the keychain." \
                "A download needs a Developer ID Application certificate (paid Apple Developer Program)." \
                "Create one in Xcode > Settings > Accounts > Manage Certificates, or at developer.apple.com," \
                "then check: security find-identity -v -p codesigning" \
                "To pick one by name, set MOUTHKEYS_SIGN_IDENTITY."
        fi
        if [ "${#found[@]}" -gt 1 ]; then
            die "several Developer ID Application identities found; set MOUTHKEYS_DEVELOPMENT_TEAM or MOUTHKEYS_SIGN_IDENTITY:" \
                "${found[@]}"
        fi
        IDENTITY="${found[0]}"
    fi
    if ! security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"${IDENTITY}\""; then
        die "the signing identity \"${IDENTITY}\" is not a valid codesigning identity in the keychain."
    fi
    echo "Signing identity: ${IDENTITY}"
}

check_notary_profile() {
    if [ "${SKIP_NOTARIZE}" = "1" ]; then
        echo "Notarization: skipped (MOUTHKEYS_SKIP_NOTARIZE=1). The result will not pass Gatekeeper elsewhere."
        return
    fi
    local out
    if ! out="$(xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" 2>&1)"; then
        die "the notarytool keychain profile \"${NOTARY_PROFILE}\" is missing or does not work:" \
            "$(printf '%s' "${out}" | head -3)" \
            "" \
            "Store it once (an app-specific password from account.apple.com > Sign-In and Security):" \
            "  xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <apple-id> --team-id <team-id>" \
            "or with an App Store Connect API key:" \
            "  xcrun notarytool store-credentials ${NOTARY_PROFILE} --key <AuthKey_XXXX.p8> --key-id <key-id> --issuer <issuer-uuid>" \
            "Use another profile with MOUTHKEYS_NOTARY_PROFILE, or sign only with MOUTHKEYS_SKIP_NOTARIZE=1."
    fi
    echo "Notary profile: ${NOTARY_PROFILE}"
}

# ---------------------------------------------------------------- build

# Release build signed to run locally ("-"). That needs no certificate, so any Mac
# with Xcode 26 can build, yet Xcode still writes the app's real entitlements into
# the signature (Fluid.entitlements plus the hardened-runtime resource entitlements
# such as com.apple.security.device.audio-input). `package` re-signs with them.
run_build() {
    cd "${PROJECT_DIR}"
    step "Release build (signed to run locally; package re-signs it)"
    xcodebuild \
        -project Fluid.xcodeproj \
        -scheme Fluid \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY=- \
        DEVELOPMENT_TEAM= \
        SDK_STAT_CACHE_ENABLE=NO \
        build
    [ -d "${BUILT_APP}" ] || die "the build succeeded but ${BUILT_APP} is missing."
    echo "Build product: ${BUILT_APP}"
    echo "Version: $(app_version "${BUILT_APP}") ($(app_build "${BUILT_APP}"))"
}

# ---------------------------------------------------------------- helpers

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }
app_version() { plist_value "$1/Contents/Info.plist" CFBundleShortVersionString; }
app_build() { plist_value "$1/Contents/Info.plist" CFBundleVersion; }

is_macho() { file -b "$1" 2>/dev/null | grep -q 'Mach-O'; }

# Writes the entitlements a signed item carries to $2, minus get-task-allow (which
# notarization rejects). Leaves $2 empty when there are none.
extract_entitlements() {
    local item="$1" out="$2"
    : > "${out}"
    codesign -d --entitlements - --xml "${item}" > "${out}" 2>/dev/null || : > "${out}"
    if [ -s "${out}" ]; then
        /usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "${out}" >/dev/null 2>&1 || true
        if [ "$(/usr/libexec/PlistBuddy -c 'Print' "${out}" 2>/dev/null | wc -l | tr -d ' ')" -le 2 ]; then
            : > "${out}"
        fi
    fi
}

# The vendored CTranscribe.xcframework ships a malformed versioned-framework layout:
# Versions/Current is a real directory and the top-level entries are copies, not
# symlinks, so a signature over it never verifies. Same fix as build.sh
# (normalize_ctranscribe_framework), without the Apple Development re-sign.
normalize_ctranscribe_layout() {
    local fw="$1/Contents/Frameworks/CTranscribe.framework"
    [ -d "${fw}" ] || return 0
    [ -L "${fw}/Versions/Current" ] && return 0
    echo "Normalizing CTranscribe.framework layout..."
    rm -rf "${fw}/Versions/A"
    mv "${fw}/Versions/Current" "${fw}/Versions/A"
    ln -s "A" "${fw}/Versions/Current"
    local entry
    for entry in CTranscribe Resources Headers Modules; do
        if [ -e "${fw}/${entry}" ] && [ ! -L "${fw}/${entry}" ]; then
            rm -rf "${fw}/${entry}"
        fi
        if [ -e "${fw}/Versions/Current/${entry}" ]; then
            ln -sfn "Versions/Current/${entry}" "${fw}/${entry}"
        fi
    done
}

sign_item() {
    local item="$1" entitlements="$2"
    local -a args=(--force --timestamp --options runtime --sign "${IDENTITY}")
    [ -s "${entitlements}" ] && args+=(--entitlements "${entitlements}")
    codesign "${args[@]}" "${item}" || die "codesign failed on ${item}."
}

# Re-signs every nested piece of code inside out, then the app, each with the
# entitlements it was built with, the hardened runtime and a secure timestamp.
sign_app() {
    local app="$1"
    local main_exe ents list
    main_exe="${app}/Contents/MacOS/$(plist_value "${app}/Contents/Info.plist" CFBundleExecutable)"
    ents="$(mktemp -t mouthkeys-ents)"
    list="$(mktemp -t mouthkeys-code)"

    extract_entitlements "${app}" "${ents}"
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "${ents}" 2>/dev/null)" != "true" ]; then
        rm -f "${ents}" "${list}"
        die "the built app lacks com.apple.security.device.audio-input; under the hardened runtime macOS would deny the microphone silently." \
            "Rebuild with scripts/release.sh build (it keeps Xcode's entitlements)."
    fi
    local app_ents="${ents}.app.plist"
    command cp -f "${ents}" "${app_ents}"

    normalize_ctranscribe_layout "${app}"

    # Nested code: bundles with an executable, and loose Mach-O files. Deepest first,
    # so each container is signed after everything it seals.
    {
        find "${app}/Contents" -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' \
            -o -name '*.appex' -o -name '*.bundle' -o -name '*.plugin' \) -print
        find "${app}/Contents" -type f -perm -u+x -print
        find "${app}/Contents" -type f \( -name '*.dylib' -o -name '*.so' \) -print
    } | sort -u > "${list}"

    local item kind count=0
    while IFS= read -r item; do
        [ "${item}" = "${main_exe}" ] && continue
        if [ -d "${item}" ]; then
            # A resource-only bundle (no executable) holds no code to sign.
            case "${item}" in
                *.framework) [ -n "$(find "${item}" -maxdepth 3 -type f -perm -u+x -print -quit)" ] || continue ;;
                *) [ -n "$(plist_value "${item}/Contents/Info.plist" CFBundleExecutable)" ] || continue ;;
            esac
        else
            is_macho "${item}" || continue
        fi
        printf '%s\t%s\n' "$(printf '%s' "${item}" | tr -cd '/' | wc -c | tr -d ' ')" "${item}"
    done < "${list}" | sort -t $'\t' -k1,1nr -k2 | cut -f2- > "${list}.sorted"

    while IFS= read -r item; do
        extract_entitlements "${item}" "${ents}"
        sign_item "${item}" "${ents}"
        kind="file"
        [ -d "${item}" ] && kind="bundle"
        printf '  signed %-6s %s\n' "${kind}" "${item#"${app}/"}"
        count=$((count + 1))
    done < "${list}.sorted"

    sign_item "${app}" "${app_ents}"
    echo "  signed app    (${count} nested items)"
    rm -f "${ents}" "${app_ents}" "${list}" "${list}.sorted"

    codesign --verify --deep --strict --verbose=2 "${app}" || die "the signed app does not verify."
}

# Submits a file and waits. Prints the notary log and stops on anything but Accepted.
notarize() {
    local file="$1"
    local result status id
    result="$(mktemp -t mouthkeys-notary).json"
    echo "Submitting $(basename "${file}") to the notary service (this waits)..."
    if ! xcrun notarytool submit "${file}" --keychain-profile "${NOTARY_PROFILE}" \
        --wait --output-format json > "${result}"; then
        cat >&2 "${result}" || true
        die "notarytool submit failed for ${file}."
    fi
    status="$(plutil -extract status raw -o - "${result}" 2>/dev/null || true)"
    id="$(plutil -extract id raw -o - "${result}" 2>/dev/null || true)"
    echo "Notary submission ${id}: ${status}"
    if [ "${status}" != "Accepted" ]; then
        [ -n "${id}" ] && xcrun notarytool log "${id}" --keychain-profile "${NOTARY_PROFILE}" >&2 || true
        die "notarization of ${file} was not accepted (status: ${status:-unknown}). The log is above."
    fi
    rm -f "${result}"
}

make_dmg() {
    local app="$1" dmg="$2"
    local stage
    stage="$(mktemp -d -t mouthkeys-dmg)"
    ditto "${app}" "${stage}/${APP_NAME}"
    ln -s /Applications "${stage}/Applications"
    rm -f "${dmg}"
    hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${stage}" -fs HFS+ \
        -format UDZO -imagekey zlib-level=9 -ov "${dmg}" >/dev/null \
        || die "hdiutil could not create ${dmg}."
    rm -rf "${stage}"
    codesign --force --timestamp --sign "${IDENTITY}" "${dmg}" || die "codesign failed on ${dmg}."
    echo "DMG: ${dmg}"
}

# ---------------------------------------------------------------- verify

run_verify() {
    local app="$1" dmg="${2:-}"
    local failed=0 out ents
    step "Verify"

    [ -d "${app}" ] || die "no app at ${app}."
    echo "-- codesign --verify --deep --strict ${app##*/}"
    codesign --verify --deep --strict --verbose=2 "${app}" 2>&1 || failed=1

    out="$(codesign -dvv "${app}" 2>&1)"
    printf '%s\n' "${out}" | grep -E '^(Identifier=|Authority=Developer ID Application|TeamIdentifier=|Timestamp=)' || true
    printf '%s\n' "${out}" | grep -q 'flags=.*runtime' || { echo "FAIL: hardened runtime is not on"; failed=1; }
    printf '%s\n' "${out}" | grep -q '^Authority=Developer ID Application' \
        || { echo "FAIL: not signed with a Developer ID Application identity"; failed=1; }

    ents="$(mktemp -t mouthkeys-ents)"
    codesign -d --entitlements - --xml "${app}" > "${ents}" 2>/dev/null || true
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "${ents}" 2>/dev/null)" = "true" ]; then
        echo "Microphone entitlement present."
    else
        echo "FAIL: com.apple.security.device.audio-input missing"; failed=1
    fi
    if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "${ents}" >/dev/null 2>&1; then
        echo "FAIL: get-task-allow is set (notarization rejects it)"; failed=1
    fi
    rm -f "${ents}"

    if [ "${SKIP_NOTARIZE}" = "1" ]; then
        echo "-- Gatekeeper and stapler checks skipped: not notarized (MOUTHKEYS_SKIP_NOTARIZE=1)."
        echo "   spctl, for reference (expected to say Unnotarized Developer ID):"
        spctl -a -vvv "${app}" 2>&1 | sed 's/^/   /' || true
    else
        echo "-- spctl -a -vvv ${app##*/}"
        spctl -a -vvv "${app}" 2>&1 || failed=1
        echo "-- xcrun stapler validate ${app##*/}"
        xcrun stapler validate "${app}" 2>&1 || failed=1
    fi

    if [ -n "${dmg}" ]; then
        [ -f "${dmg}" ] || die "no DMG at ${dmg}."
        echo "-- codesign --verify ${dmg##*/}"
        codesign --verify --strict --verbose=2 "${dmg}" 2>&1 || failed=1
        if [ "${SKIP_NOTARIZE}" != "1" ]; then
            echo "-- spctl -a -vvv -t install ${dmg##*/}"
            if ! spctl -a -vvv -t install "${dmg}" 2>&1; then
                echo "-- spctl -a -vvv -t open --context context:primary-signature ${dmg##*/}"
                spctl -a -vvv -t open --context context:primary-signature "${dmg}" 2>&1 || failed=1
            fi
            echo "-- xcrun stapler validate ${dmg##*/}"
            xcrun stapler validate "${dmg}" 2>&1 || failed=1
        fi
        echo "-- shasum -a 256"
        shasum -a 256 "${dmg}"
    fi

    [ "${failed}" -eq 0 ] || die "verification failed; see the lines marked above."
    echo "Verification passed."
}

# ---------------------------------------------------------------- package

run_package() {
    local source_app="${1:-${BUILT_APP}}"
    [ -d "${source_app}" ] || die "no built app at ${source_app}. Run scripts/release.sh build first, or pass the app's path."
    [ "$(plist_value "${source_app}/Contents/Info.plist" CFBundleIdentifier)" = "com.stage11.mouthkeys" ] \
        || die "${source_app} is not the Release app (com.stage11.mouthkeys)."

    resolve_identity
    check_notary_profile

    local version build app zip dmg
    version="$(app_version "${source_app}")"
    build="$(app_build "${source_app}")"
    [ -n "${version}" ] || die "cannot read CFBundleShortVersionString from ${source_app}."
    echo "Packaging MouthKeys ${version} (${build})"

    mkdir -p "${DIST_DIR}"
    app="${DIST_DIR}/${APP_NAME}"
    zip="${DIST_DIR}/MouthKeys-${version}-notarize.zip"
    dmg="${DIST_DIR}/MouthKeys-${version}.dmg"

    # Work on a copy, so the build product is never modified.
    rm -rf "${app}"
    ditto "${source_app}" "${app}"

    step "Sign with Developer ID"
    sign_app "${app}"

    if [ "${SKIP_NOTARIZE}" != "1" ]; then
        step "Notarize the app"
        rm -f "${zip}"
        ditto -c -k --keepParent "${app}" "${zip}"
        notarize "${zip}"
        rm -f "${zip}"
        xcrun stapler staple "${app}" || die "stapling the app failed."
    fi

    step "Build the DMG"
    make_dmg "${app}" "${dmg}"

    if [ "${SKIP_NOTARIZE}" != "1" ]; then
        step "Notarize the DMG"
        notarize "${dmg}"
        xcrun stapler staple "${dmg}" || die "stapling the DMG failed."
    fi

    run_verify "${app}" "${dmg}"
    echo
    echo "Release artifact: ${dmg}"
    [ "${SKIP_NOTARIZE}" = "1" ] && echo "NOT notarized: for a signing check only, not for upload."
    return 0
}


# ---------------------------------------------------------------- ship

REPO_SLUG="BenevolentFutures/MouthKeys"
BUILD_HOST="${MOUTHKEYS_BUILD_HOST:-atlas}"
INSTALLED_APP="/Applications/${APP_NAME}"
INSTALLED_LOG="${HOME}/Library/Logs/MouthKeys/Fluid.log"
RELEASE_ID="com.stage11.mouthkeys"

source_version() { plist_value "${PROJECT_DIR}/Info.plist" CFBundleShortVersionString; }
ship_dir() { printf '%s' "${MOUTHKEYS_SHIP_DIR:-${HOME}/Backups/mouthkeys-release-$1}"; }

# Release builds come from what is on GitHub, never from a working tree.
check_clean_main() {
    cd "${PROJECT_DIR}"
    git fetch -q origin main --tags || die "git fetch failed."
    [ -z "$(git status --porcelain --untracked-files=no)" ] || die "the checkout has local changes; ship builds origin/main only."
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
        || die "HEAD is not origin/main. Merge the version bump, then: git switch main && git pull --ff-only"
}

# A failed main CI run on this commit stops the release; a pending or missing one only warns
# (the macOS runner queue lags, and the bump PR's own CI already ran on the same tree).
check_main_ci() {
    local sha="$1" conclusion
    conclusion="$(gh run list --repo "${REPO_SLUG}" --commit "${sha}" --json conclusion,status \
        --jq '[.[] | select(.status=="completed") | .conclusion] | if any(.=="failure") then "failure" elif length>0 then "success" else "none" end' 2>/dev/null || echo unknown)"
    case "${conclusion}" in
        failure) die "CI failed on ${sha:0:8}; fix main first." ;;
        success) echo "CI on ${sha:0:8}: passed" ;;
        *) echo "CI on ${sha:0:8}: not finished (${conclusion}); the bump PR's run covers the same tree. Continuing." ;;
    esac
}

# Release build of a commit on the build host from a fresh clone, copied back with ditto (which
# keeps the framework symlinks). Prints nothing but progress; the app lands in $2.
run_remote_build() {
    local sha="$1" dest="$2"
    local url remote
    url="https://github.com/${REPO_SLUG}.git"
    mkdir -p "${dest}"
    rm -rf "${dest:?}/${APP_NAME}"
    if [ "${BUILD_HOST}" = "local" ]; then
        local clone
        clone="$(mktemp -d -t mouthkeys-release-clone)"
        git clone -q --filter=blob:none "${url}" "${clone}/repo"
        git -C "${clone}/repo" checkout -q "${sha}"
        "${clone}/repo/scripts/release.sh" build
        ditto "${clone}/repo/DerivedData/Build/Products/Release/${APP_NAME}" "${dest}/${APP_NAME}"
        rm -rf "${clone}"
    else
        step "Release build of ${sha:0:8} on ${BUILD_HOST} (about 5 minutes)"
        remote="mouthkeys-release-builds/${sha:0:12}"
        # shellcheck disable=SC2029
        ssh -o ServerAliveInterval=30 -o ConnectTimeout=10 "${BUILD_HOST}" \
            "set -e; rm -rf ~/${remote}; mkdir -p ~/${remote}; cd ~/${remote}
             git clone -q --filter=blob:none '${url}' repo; cd repo; git checkout -q '${sha}'
             if ! scripts/release.sh build > ../build.log 2>&1; then tail -40 ../build.log; exit 1; fi
             tail -3 ../build.log" \
            || die "the Release build on ${BUILD_HOST} failed (log: ${BUILD_HOST}:~/${remote}/build.log)."
        # shellcheck disable=SC2029
        ssh "${BUILD_HOST}" "cd ~/${remote}/repo/DerivedData/Build/Products/Release && ditto -c -k --keepParent ${APP_NAME} -" \
            | ditto -x -k - "${dest}" || die "copying the build back from ${BUILD_HOST} failed."
    fi
    [ "$(plist_value "${dest}/${APP_NAME}/Contents/Info.plist" CFBundleIdentifier)" = "${RELEASE_ID}" ] \
        || die "the copied build at ${dest}/${APP_NAME} is not ${RELEASE_ID}."
    echo "Built: ${dest}/${APP_NAME} $(app_version "${dest}/${APP_NAME}") ($(app_build "${dest}/${APP_NAME}"))"
}

# Quitting the app mid-dictation loses the recording (2026-10-05: an install test quit it 44 s into
# one). In progress: the last START() is newer than the last stop, cancel or delivery.
DICTATION_START='START\(\) called'
DICTATION_END='STOP\(\) called|Stopping recording|OVERLAY_OUTCOME|Application will terminate'

dictation_in_progress() {
    [ -f "${INSTALLED_LOG}" ] || return 1
    local last_start last_end
    last_start="$(grep -nE "${DICTATION_START}" "${INSTALLED_LOG}" | tail -1 | cut -d: -f1)"
    last_end="$(grep -nE "${DICTATION_END}" "${INSTALLED_LOG}" | tail -1 | cut -d: -f1)"
    [ -n "${last_start}" ] && [ "${last_start}" -gt "${last_end:-0}" ]
}

# Seconds since the last dictation start or end in the log (a large number when there is none).
seconds_since_last_dictation_event() {
    local stamp at now
    stamp="$(grep -E "${DICTATION_START}|${DICTATION_END}" "${INSTALLED_LOG}" 2>/dev/null | tail -1 | cut -c2-9)"
    [ -n "${stamp}" ] || { echo 99999; return; }
    at="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date +%Y-%m-%d) ${stamp}" +%s 2>/dev/null || echo 0)"
    now="$(date +%s)"
    # Before midnight, read from after it: treat as long ago.
    [ "${at}" -le "${now}" ] && echo $((now - at)) || echo 99999
}

# Waits (up to 30 minutes) until no dictation is running and none ended in the last 10 s.
wait_for_idle_dictation() {
    pgrep -x MouthKeys >/dev/null || return 0
    local waited=0 announced=0
    while dictation_in_progress || [ "$(seconds_since_last_dictation_event)" -lt 10 ]; do
        if [ "${announced}" -eq 0 ]; then
            echo "MouthKeys is dictating (or just finished); waiting until it has been idle for 10 s..."
            announced=1
        fi
        [ "${waited}" -ge 1800 ] && die "MouthKeys stayed busy for 30 minutes. Nothing was changed."
        sleep 2
        waited=$((waited + 2))
    done
}

designated_requirement() { codesign -d -r- "$1" 2>&1 | sed -n 's/^designated => //p'; }
signer_lines() { codesign -dvv "$1" 2>&1 | grep -E '^(Authority|TeamIdentifier)=' || true; }

# Puts a Developer ID signed app in /Applications the way INSTALL-CHECKLIST.md "Install over a
# Developer ID app" does: the signature must match the installed app's (or, on the one install
# that changes the bundle ID, its signer), a verified backup and a rollback script come first,
# the app is quit and swapped, and the hotkey must arm. Never quits the app before every check
# has passed.
run_install() {
    local new_app="$1"
    [ -d "${new_app}" ] || die "no app at ${new_app}."
    [ "$(plist_value "${new_app}/Contents/Info.plist" CFBundleIdentifier)" = "${RELEASE_ID}" ] \
        || die "${new_app} is not ${RELEASE_ID}."
    signer_lines "${new_app}" | grep -q '^Authority=Developer ID Application' \
        || die "${new_app} is not signed with Developer ID. Package it first (scripts/release.sh package)."

    step "Install $(app_version "${new_app}") ($(app_build "${new_app}")) over ${INSTALLED_APP}"
    local identity_change=0 installed_id=""
    if [ -d "${INSTALLED_APP}" ]; then
        installed_id="$(plist_value "${INSTALLED_APP}/Contents/Info.plist" CFBundleIdentifier)"
        echo "Installed: ${installed_id} $(app_version "${INSTALLED_APP}") ($(app_build "${INSTALLED_APP}"))"
        if [ "${installed_id}" = "${RELEASE_ID}" ]; then
            [ "$(designated_requirement "${INSTALLED_APP}")" = "$(designated_requirement "${new_app}")" ] \
                || die "the new app's designated requirement differs from the installed app's." \
                    "Installing it would silently cut Accessibility (CLAUDE.md, Agent pitfalls). Nothing was changed." \
                    "installed: $(designated_requirement "${INSTALLED_APP}")" \
                    "new:       $(designated_requirement "${new_app}")"
            echo "Signature: designated requirement matches."
        else
            identity_change=1
            [ "$(signer_lines "${INSTALLED_APP}")" = "$(signer_lines "${new_app}")" ] \
                || die "the installed app (${installed_id}) has another signer. Nothing was changed."
            if defaults read "${RELEASE_ID}" >/dev/null 2>&1 || [ -e "${HOME}/Library/Application Support/MouthKeys" ]; then
                die "data already exists under ${RELEASE_ID}, so the one-time copy from ${installed_id} would be skipped or merged." \
                    "Move it aside first (INSTALL-CHECKLIST.md section 0, step 0). Nothing was changed."
            fi
            echo "Identity change: ${installed_id} -> ${RELEASE_ID}. Same signer. The first launch copies"
            echo "the old data once; Microphone and Accessibility are granted again (checklist section 0)."
        fi
    fi

    # Another copy of the bundle ID signed by someone else poisons the Accessibility grant.
    local copy other=0
    while IFS= read -r copy; do
        [ -n "${copy}" ] || continue
        case "${copy}" in "${INSTALLED_APP}"|"${new_app}"|"$(dirname "${new_app}")"/*) continue ;; esac
        if [ "$(signer_lines "${copy}")" != "$(signer_lines "${new_app}")" ]; then
            echo "Another copy of ${RELEASE_ID} with another signer: ${copy}"
            other=1
        fi
    done < <(mdfind "kMDItemCFBundleIdentifier == '${RELEASE_ID}'" 2>/dev/null)
    [ "${other}" -eq 0 ] || die "delete the copies above and empty the Trash first (CLAUDE.md, Agent pitfalls). Nothing was changed."

    local backup=""
    if [ -d "${INSTALLED_APP}" ]; then
        backup="${HOME}/Backups/mouthkeys-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "${backup}"
        ditto "${INSTALLED_APP}" "${backup}/${APP_NAME}"
        codesign --verify --deep --strict "${backup}/${APP_NAME}" 2>/dev/null \
            || die "the backup at ${backup} does not verify. Nothing was changed."
        cat > "${backup}/rollback.sh" <<ROLLBACK
#!/bin/bash
# Puts back the MouthKeys that scripts/release.sh install replaced on $(date '+%Y-%m-%d %H:%M').
set -euo pipefail
osascript -e 'quit app "MouthKeys"' >/dev/null 2>&1 || true
for _ in \$(seq 1 40); do pgrep -x MouthKeys >/dev/null || break; sleep 0.5; done
pgrep -x MouthKeys >/dev/null && { echo "MouthKeys is still running; quit it and run this again. Nothing was changed." >&2; exit 1; }
rm -rf "${INSTALLED_APP}.rollback"
ditto "${backup}/${APP_NAME}" "${INSTALLED_APP}.rollback"
rm -rf "${INSTALLED_APP}"
mv "${INSTALLED_APP}.rollback" "${INSTALLED_APP}"
open "${INSTALLED_APP}"
echo "Restored the backup from ${backup}."
ROLLBACK
        chmod +x "${backup}/rollback.sh"
        echo "Backup: ${backup} (verified)"
        echo "Rollback: bash ${backup}/rollback.sh"
    fi

    wait_for_idle_dictation
    if pgrep -x MouthKeys >/dev/null; then
        # A dictation that began during the last checks still blocks the quit.
        dictation_in_progress && die "a dictation started just now. Nothing was changed; run install again."
        osascript -e 'quit app "MouthKeys"' >/dev/null 2>&1 || true
        local waited=0
        while pgrep -x MouthKeys >/dev/null; do
            [ "${waited}" -ge 40 ] && die "MouthKeys did not quit within 20 s. Nothing was changed."
            sleep 0.5
            waited=$((waited + 1))
        done
    fi

    rm -rf "${INSTALLED_APP}.new" "${INSTALLED_APP}.old"
    ditto "${new_app}" "${INSTALLED_APP}.new"
    [ -d "${INSTALLED_APP}" ] && mv "${INSTALLED_APP}" "${INSTALLED_APP}.old"
    mv "${INSTALLED_APP}.new" "${INSTALLED_APP}"
    rm -rf "${INSTALLED_APP}.old"

    local log_lines=0
    [ -f "${INSTALLED_LOG}" ] && log_lines="$(wc -l < "${INSTALLED_LOG}" | tr -d ' ')"
    open "${INSTALLED_APP}"
    echo "Installed and opened $(app_version "${INSTALLED_APP}") ($(app_build "${INSTALLED_APP}"))."

    # The hotkey tap reports within a few seconds of launch.
    local state="" tries=0
    while [ "${tries}" -lt 40 ]; do
        sleep 0.5
        tries=$((tries + 1))
        [ -f "${INSTALLED_LOG}" ] || continue
        state="$(tail -n +"$((log_lines + 1))" "${INSTALLED_LOG}" | grep -o 'HOTKEY_TAP state=[a-z_]*' | tail -1 | cut -d= -f2)"
        [ "${state}" = "installed" ] && break
    done
    if [ "${identity_change}" -eq 1 ]; then
        grep 'IDENTITY_MIGRATION finished' "${INSTALLED_LOG}" 2>/dev/null | tail -1 || true
        echo "Next: grant Accessibility to the new MouthKeys row (the old row is the earlier identity),"
        echo "then press the hotkey and Allow the microphone. HOTKEY_TAP state=installed follows."
    elif [ "${state}" = "installed" ]; then
        echo "Hotkey: HOTKEY_TAP state=installed"
    else
        die "the hotkey did not arm (HOTKEY_TAP state=${state:-none} after 20 s); the signature may not match." \
            "${backup:+Roll back: bash \"${backup}/rollback.sh\"}"
    fi
}

run_publish() {
    local version="${1:-$(source_version)}" dmg="${2:-}"
    local tag="v${version}" local_sum remote_sum
    step "Publish ${tag}"
    [ "$(gh release view "${tag}" --repo "${REPO_SLUG}" --json isDraft --jq .isDraft 2>/dev/null)" = "true" ] \
        || die "${tag} is not a draft release (already published, or not drafted)."
    gh release edit "${tag}" --repo "${REPO_SLUG}" --draft=false --latest >/dev/null
    remote_sum="$(curl -fsSL "https://github.com/${REPO_SLUG}/releases/download/${tag}/MouthKeys-${version}.dmg" | shasum -a 256 | cut -d' ' -f1)"
    echo "Download sha256: ${remote_sum}"
    [ -z "${dmg}" ] && dmg="$(ship_dir "${version}")/dist/MouthKeys-${version}.dmg"
    if [ -f "${dmg}" ]; then
        local_sum="$(shasum -a 256 "${dmg}" | cut -d' ' -f1)"
        [ "${local_sum}" = "${remote_sum}" ] || die "the download does not match ${dmg} (${local_sum})."
        echo "Matches ${dmg}."
    fi
    echo "Published: https://github.com/${REPO_SLUG}/releases/tag/${tag}"
}

run_ship() {
    local notes=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --notes) notes="${2:-}"; shift 2 ;;
            *) die "unknown option for ship: $1 (use --notes FILE)." ;;
        esac
    done
    [ -n "${notes}" ] && [ -s "${notes}" ] || die "ship needs release notes: scripts/release.sh ship --notes FILE" \
        "Style: lowercase sentences, headings ending in a period, no em-dashes (see the last release)."
    notes="$(cd "$(dirname "${notes}")" && pwd)/$(basename "${notes}")"

    step "Preflight"
    check_clean_main
    local sha version tag work
    sha="$(git -C "${PROJECT_DIR}" rev-parse HEAD)"
    version="$(source_version)"
    tag="v${version}"
    work="$(ship_dir "${version}")"
    echo "Releasing MouthKeys ${version} ($(plist_value "${PROJECT_DIR}/Info.plist" CFBundleVersion)) from ${sha:0:8}"
    if gh release view "${tag}" --repo "${REPO_SLUG}" --json isDraft --jq .isDraft 2>/dev/null | grep -q false; then
        die "${tag} is already published. Bump the version in Info.plist (a PR to main) first."
    fi
    gh auth status >/dev/null 2>&1 || die "gh is not logged in."
    resolve_identity
    check_notary_profile
    [ "${SKIP_NOTARIZE}" = "1" ] && die "ship publishes; it never runs with MOUTHKEYS_SKIP_NOTARIZE=1."
    check_main_ci "${sha}"
    [ "${BUILD_HOST}" = "local" ] || ssh -o ConnectTimeout=10 "${BUILD_HOST}" true 2>/dev/null \
        || die "cannot reach the build host ${BUILD_HOST} (set MOUTHKEYS_BUILD_HOST, or local)."

    run_remote_build "${sha}" "${work}/build"
    [ "$(app_version "${work}/build/${APP_NAME}")" = "${version}" ] || die "the build's version is not ${version}."

    DIST_DIR="${work}/dist"
    run_package "${work}/build/${APP_NAME}"
    # The locally signed build has the release bundle ID and another signer: left on disk it can
    # poison the Accessibility grant (CLAUDE.md, Agent pitfalls).
    rm -rf "${work}/build"

    local dmg="${work}/dist/MouthKeys-${version}.dmg"
    step "Draft ${tag}"
    if gh release view "${tag}" --repo "${REPO_SLUG}" >/dev/null 2>&1; then
        gh release upload "${tag}" "${dmg}" --clobber --repo "${REPO_SLUG}"
        gh release edit "${tag}" --repo "${REPO_SLUG}" --notes-file "${notes}" --target "${sha}" >/dev/null
    else
        gh release create "${tag}" --draft --repo "${REPO_SLUG}" --target "${sha}" \
            --title "MouthKeys ${version}" --notes-file "${notes}" "${dmg}" >/dev/null
    fi
    echo "Draft ready (not public yet)."

    run_install "${work}/dist/${APP_NAME}"

    echo
    if [ -t 0 ]; then
        echo "Dictate into c11 once. When the text lands, type publish to make ${tag} public."
        local answer=""
        read -r -p "> " answer || true
        if [ "${answer}" = "publish" ]; then
            run_publish "${version}" "${dmg}"
            return 0
        fi
        echo "Not published."
    fi
    echo "When dictation works: scripts/release.sh publish ${version}"
}

case "${1:-all}" in
    all)
        # Check the credentials before a long build, not after it.
        resolve_identity
        check_notary_profile
        run_build
        run_package "${BUILT_APP}"
        ;;
    build)
        run_build
        ;;
    package)
        run_package "${2:-${BUILT_APP}}"
        ;;
    verify)
        run_verify "${2:-${DIST_DIR}/${APP_NAME}}" "${3:-}"
        ;;
    ship)
        shift
        run_ship "$@"
        ;;
    remote-build)
        check_clean_main
        run_remote_build "$(git -C "${PROJECT_DIR}" rev-parse HEAD)" "${2:-$(ship_dir "$(source_version)")/build}"
        echo "Package it with: scripts/release.sh package <that app>; delete the unsigned copy afterwards."
        ;;
    install)
        run_install "${2:-${DIST_DIR}/${APP_NAME}}"
        ;;
    publish)
        run_publish "${2:-}"
        ;;
    -h|--help|help)
        sed -n '3,39p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *)
        die "unknown command: $1 (use ship, all, build, remote-build, package, verify, install or publish)."
        ;;
esac
