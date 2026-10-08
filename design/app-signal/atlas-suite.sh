#!/bin/bash
# Run the full MouthKeys test suite on Atlas at one exact commit.
#
#   design/app-signal/atlas-suite.sh <label> <commit>
#
# The commit must already be pushed to GitHub: Atlas fetches it from the public repo into a
# mirror at ~/atlas-jobs/mk-ds/mirror and tests it in a throwaway worktree with ad-hoc signing
# (Atlas has no Apple Development identity). Prints the tested SHA, the test count, the result
# and the log path on Atlas. Exits 0 only when the suite passed.
set -euo pipefail
label=${1:?usage: atlas-suite.sh <label> <commit>}
sha=$(git rev-parse "${2:?usage: atlas-suite.sh <label> <commit>}^{commit}")
run="$label-${sha:0:7}"

ssh -o BatchMode=yes -o ConnectTimeout=10 atlas /bin/zsh -l -s -- "$sha" "$run" <<'REMOTE'
set -u
sha=$1; run=$2
base=$HOME/atlas-jobs/mk-ds
dir=$base/runs/$run
log=$dir.log
mkdir -p "$base/runs"

retry() { local n; for n in 1 2 3; do "$@" && return 0; sleep $((n * 5)); done; return 1; }

if [ ! -d "$base/mirror/.git" ]; then
  retry git clone -q https://github.com/BenevolentFutures/MouthKeys "$base/mirror" || { echo "clone failed"; exit 2; }
fi
retry git -C "$base/mirror" fetch -q origin "$sha" || { echo "fetch of $sha failed: is it pushed?"; exit 2; }
if [ -d "$dir" ]; then git -C "$base/mirror" worktree remove --force "$dir" 2>/dev/null || /bin/rm -rf "$dir"; fi
git -C "$base/mirror" worktree prune
retry git -C "$base/mirror" worktree add -q --detach "$dir" "$sha" || { echo "worktree add failed"; exit 2; }

cd "$dir"
env -u CLAUDECODE xcodebuild -project Fluid.xcodeproj -scheme Fluid -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath DerivedData DEVELOPMENT_TEAM=UKQ4QALWD4 \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO SDK_STAT_CACHE_ENABLE=NO test > "$log" 2>&1
rc=$?

echo "tested=$(git rev-parse HEAD)"
grep -E "Executed [0-9]+ tests" "$log" | tail -1
grep -E "\*\* TEST (SUCCEEDED|FAILED) \*\*" "$log" | tail -1
echo "log=atlas:$log exit=$rc"

cd "$base"
git -C "$base/mirror" worktree remove --force "$dir" 2>/dev/null || /bin/rm -rf "$dir"
exit $rc
REMOTE
