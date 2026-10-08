#!/bin/bash
# Incremental Debug build, or a single test target, on Hyperion. Run from a worktree root.
#
#   design/app-signal/local-build.sh build
#   design/app-signal/local-build.sh test -only-testing:FluidDictationIntegrationTests/SomeTests
#
# At most two of these run at once across every seat: each run holds one of two slots under
# ~/Projects/MouthKeys-worktrees/.xcodebuild-slots and waits for a free one. A slot whose holder
# died is reclaimed. Full suites never run here: use design/app-signal/atlas-suite.sh.
set -uo pipefail
slots=$HOME/Projects/MouthKeys-worktrees/.xcodebuild-slots
mkdir -p "$slots"
slot=""
while [ -z "$slot" ]; do
  for n in 1 2; do
    d=$slots/$n
    if mkdir "$d" 2>/dev/null; then
      echo $$ > "$d/pid"
      slot=$d
      break
    fi
    holder=$(cat "$d/pid" 2>/dev/null || true)
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      /bin/rm -rf "$d"
    fi
  done
  [ -z "$slot" ] && sleep 10
done
trap '/bin/rm -rf "$slot"' EXIT

action=${1:-build}
shift || true
xcodebuild -project Fluid.xcodeproj -scheme Fluid -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData DEVELOPMENT_TEAM=UKQ4QALWD4 SDK_STAT_CACHE_ENABLE=NO "$@" "$action"
