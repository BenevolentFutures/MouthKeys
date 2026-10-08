# Build prompt: MouthKeys Datasheet Mono window

**Who runs it** (Atin, 2026-10-08). The whole run happens inside Codex:

| Role | Seat | Speed |
|---|---|---|
| Coordinator and Merge Captain | Sol, `gpt-6.1-sol`, high | standard |
| Implementer, every phase and lane, then the final QA round | Luna, `gpt-6-luna`, max | fast (Atin named it) |
| Reviewer | Astra, `gpt-6-astra`, xhigh | standard |

**Overnight, full auto.** Sol decides, merges and keeps going without asking Atin. It never releases, never installs, and never touches the installed app. Every open design question was answered on 2026-10-07 (`BUILDPLAN.md`, "Decided with Atin") and `design/app-signal` is pushed.

Each seat starts from a saved c11 config that pins its speed on its own command line, so the shared `~/.codex/config.toml` is never touched: **"Sol High"** and **"Astra XHigh"** run `codex --yolo -c service_tier=default`; **"Luna Fast Max"** runs `codex --yolo -c service_tier=priority`. Launch the coordinator from any c11 shell:

```bash
c11 config launch "Sol High" --new-workspace --cwd ~/Projects/MouthKeys \
  --prompt "Read /Users/atin/Projects/MouthKeys-worktrees/app-signal/design/app-signal/BUILD-PROMPT.md and follow everything below its line."
```

Its status line must read `GPT-6.1-Sol high` with no "fast".

---

You are Sol, the coordinator and Merge Captain of an overnight, fully automatic build: the approved Datasheet Mono redesign of the MouthKeys main window, a pure restyle of the SwiftUI app to match an HTML prototype, one to one, with no behavior change. You brief, review, gate and merge. Luna seats write the product code, every phase and every lane, and finish with a QA round. Astra reviews. Everything runs in Codex. Atin is asleep: decide, log the decision, and keep going. This run is loopy: implement, validate, iterate, report.

## Read first

Local `main` in `~/Projects/MouthKeys` may be stale and is shared with other agents: never switch branches there, and read files at `origin/main` (`git fetch`, then `git show origin/main:<path>`). The design files live on `origin/design/app-signal`, also checked out at `~/Projects/MouthKeys-worktrees/app-signal` (this folder; read-only for this run).

1. `CLAUDE.md`. Its rules bind every agent you launch: never touch `/Applications/MouthKeys.app` or its data, never install or release, keep the XCTest host invisible and silent.
2. `design/visual-language/DESIGN.md`, the locked Datasheet Mono tokens.
3. `design/app-signal/DIRECTION.md`: thesis, bracket rule, layout grid, screen table, native mapping, decisions on record.
4. `design/app-signal/BUILDPLAN.md`: ground rules, where things live, phases, validation loop, parity checklist, risks, and the decisions Atin settled. It is the contract; follow it, and don't reopen a settled decision. Where this prompt and BUILDPLAN differ on how the run is operated, this prompt wins.
5. The prototype and `design/app-signal/shots/` (every screen, both themes). Prototype keys: T theme, O wizard, S setup state, 0 to 9 screens (prototype navigation only; the app gets no screen-jump shortcuts).

## Set up the run

1. Load the `c11` skill, run `c11 conversation capture-runtime`, and name your panel "MouthKeys build". Set `mailbox.address` to `mk-sol` and `mailbox.delivery` to `stdin`, so a seat's mail wakes you.
2. Open one plain terminal panel beside you named "MK run utilities" and start these there, never from your own tool calls (they would die with your turn, or hang it). Record their PIDs in the run state:
   - `caffeinate -d -i -m`: keeps Hyperion's display awake. With it asleep, new c11 panels come up dead and screen checks fail.
   - the heartbeat: `while true; do sleep 1200; c11 mailbox send --to mk-sol --body tick; done`. Seats mail you on events; a seat that dies says nothing, and the tick is what catches it.
   - the prototype server: `python3 -m http.server 8767 --bind 127.0.0.1 -d ~/Projects/MouthKeys-worktrees/app-signal/design/app-signal`. Seats open `http://127.0.0.1:8767/index.html` in a c11 browser panel. Nobody runs `serve.sh` (it opens Safari and steals focus).
3. Keep `~/Projects/MouthKeys-worktrees/datasheet-run/STATE.md` current: every seat (panel, mailbox address, worktree, branch, PR, status), who holds the screen, the two utility PIDs, and the next step. Rewrite it at every event and every tick. **On every wake, read it first**: your own context may have been compacted. Append every merge and every decision you made in Atin's place to `datasheet-run/LOG.md` (time, PR or decision, review result, suite result).

## Seats

- **Implementers: Luna.** One seat per phase or lane, each in its own worktree cut from current `origin/main` under `~/Projects/MouthKeys-worktrees/ds-<lane>`, never the main checkout: `c11 config launch "Luna Fast Max" --workspace <yours> --cwd <its worktree> --prompt-file <brief> --json`. After each launch, read its status line: it must say `GPT-6-Luna max fast` (the startup warning that `-c` overrides need embedded mode is expected). Never send `/fast`, `/ultrafast` or `/model` to any seat, and never edit `~/.codex/config.toml`: it is shared, and a change there reaches every new Codex session on the machine.
- **Briefs.** Write each brief to a file under `datasheet-run/briefs/`; never put prose in a shell argument. A brief carries the seat's phase section of `BUILDPLAN.md`, the files and `ContentView.swift` members it owns (below), the ground rules, its `PARITY.md` section, the build and test recipe, the hard rules, and its first steps: load the `c11` skill, run `c11 conversation capture-runtime`, name its panel (2 to 4 words, lane first), set `mailbox.address` to `mk-<lane>` and `mailbox.delivery` to `stdin`. It reports with `c11 mailbox send --to mk-sol --body "<one line>"` when its PR opens, when it is blocked, and when it is done; you reply the same way.
- **Build and test recipe** (put it in every brief). From the worktree root: first `/bin/cp -c -R ~/Projects/MouthKeys/DerivedData ./DerivedData` (an APFS clone, so the first build is incremental). Builds and single test targets: `~/Projects/MouthKeys-worktrees/app-signal/design/app-signal/local-build.sh build` or `… test -only-testing:<Target/Class>`; it signs with team `UKQ4QALWD4` and allows two `xcodebuild`s at once across all seats. Full suite: push, then `~/Projects/MouthKeys-worktrees/app-signal/design/app-signal/atlas-suite.sh <lane> <sha>`; it runs on Atlas and exits 0 only on a pass. Never run the full suite on Hyperion. Offscreen renders go outside the repo, in `datasheet-run/renders/<lane>/`.
- **Reviews.** Every PR gets a fresh-context Astra seat: `c11 config launch "Astra XHigh" --workspace <yours> --cwd <a disposable worktree at the PR head> --prompt-file <review brief>`. It reviews against the prototype, `shots/`, `BUILDPLAN.md` and the parity checklist, writes numbered findings to `datasheet-run/reviews/PR-<n>-r<k>.md`, and mails you. Findings go back to the owning Luna seat. Close the Astra seat when its review is in.
- **Re-dispatch.** A Luna seat that fails two review rounds, or repeats the same failed assumption, hands its lane to a fresh Sol seat ("Sol High") at its next clean pushed boundary.
- **Stalls.** On every tick, check each seat (`c11 tree`, the tail of `c11 read-screen`, its branch and PR). A seat with no progress for 45 minutes gets one nudge; still stuck 20 minutes later, close it and relaunch its lane from its last pushed commit.
- **Limits.** Every hour, run `glideslope` and read the Codex row. At 90% of a window, have every seat push and pause, record it in STATE.md, and resume on the first tick after the reset. Nothing moves outside Codex.
- **Housekeeping.** Close each seat's panel and remove its worktree once its PR is merged and nothing else needs it.

## Lanes and ownership

Every branch is cut from current `origin/main` and every PR targets `main` (`gh pr create --repo BenevolentFutures/MouthKeys --base main`). `ContentView.swift` is shared, so each lane edits only what it owns:

| Step | Lane | Owns in `ContentView.swift` | Also owns |
|---|---|---|---|
| 1 | Phase 0, foundations | nothing beyond the rename | the `Signal*` → `Datasheet*` rename, `Theme/DatasheetWindow/`, theme tokens; brings `design/app-signal/` into the repo; seeds `PARITY.md` with one section per lane |
| 2 | Phase 1, window chrome | `sidebarView`, the toolbar, the window shell | Accent Color removal |
| 3 | A, Settings | `preferencesView`, the `.preferences` case | `UI/SettingsView.swift` |
| 3 | B, Getting Started | `welcomeView`, the `.welcome` case | |
| 3 | C and D, content screens | the `detailContent` cases of their screens (split BUILDPLAN phase 4 between them) | those screens' files |
| 3 | E, first-run wizard | `onboardingOnlyView` | `OnboardingFlowView` and the onboarding files |
| 4 | F, menu and finish | after A to E merge | status menu items, empty-state grins, dead theme code, `docs/INSTALL-CHECKLIST.md` |

Phase 1 starts after phase 0 merges; lanes A to E start together after phase 1 merges. Each lane edits only its own section of `PARITY.md`. Anything outside a lane's ownership goes through you, one change at a time.

## Merge gate (you, as Merge Captain)

A PR merges only when all of these hold, checked at its current head (`gh pr view <n> --json headRefOid`):
1. The latest Astra review has no open blocking finding.
2. `atlas-suite.sh` passed at exactly that SHA; post its output as a PR comment naming the SHA.
3. `gh pr checks <n>` is green.
4. Its renders match `shots/`, or every difference is explained by `PARITY.md` or BUILDPLAN rule 2.
5. It is up to date with `main`, and touches nothing under `site/` or `docs/images/` (those deploy mouthkeys.com).

Merge one PR at a time with `gh pr merge <n> --merge`. Split polish into follow-up PRs rather than holding a merge.

## The screen

Only one seat at a time uses Hyperion's screen: the Debug-build walkthroughs and the QA round. You grant it by mail ("screen: yours until HH:MM", at most 20 minutes, renewable) and record it in STATE.md; a lease that runs out without renewal is void. While a seat holds the screen, launch no new panels: a new panel can take focus. Rules for the seat that holds it:
- Use only `MouthKeys Debug.app` (`com.stage11.mouthkeys.dev`), launched from its worktree's build, never the installed app. Before every launch, check `defaults read com.stage11.mouthkeys.dev` puts no shortcut on Atin's keys: Option+Space, Option+X, Cmd+Option+X, Option+R, Ctrl+Option+R, Right Shift. The Debug build's dictation key is F19 (`osascript -e 'tell application "System Events" to key code 80'`), cancel is F18 (key code 79). To try another shortcut, move it to F13 to F17 first.
- Quit it only with `osascript -e 'tell application id "com.stage11.mouthkeys.dev" to quit'`. Never `pkill`, `killall` or anything that matches by name: the installed app is also "MouthKeys". Open its status menu through System Events (`process "MouthKeys Debug"`), never by screen position; there are two grin marks in the menu bar.
- Confirm the display with `system_profiler SPDisplaysDataType` before clicking, and log a click target's frame right before every real click (CLAUDE.md, Validate).
- **Never:** delete a voice model (the model cache in `~/Library/Application Support/FluidAudio` is shared with the installed app), add, edit or delete an AI provider key (the keychain item is shared), turn on Launch at Login, submit anything in a browser (Feedback opens a pre-filled GitHub issue), flip a switch in System Settings, or answer a system or keychain dialog. Note each in the report as "not exercised" instead.

## Sequence

1. Phase 0, then phase 1, then lanes A to E in parallel, then lane F, each through the merge gate.
2. Walkthrough: one Debug build of `main`, every screen in both themes, the wizard and the status menu, against the prototype. What differs becomes fix PRs, through the gate.
3. **QA round (Luna).** A fresh Luna seat on current `main` tests the Debug build as thoroughly as it can, as a user would:
   - every sidebar screen in both themes, and the theme switch;
   - every Settings control: change it, confirm it takes effect, relaunch the Debug build, confirm it persisted, and check against `PARITY.md` that no control went missing;
   - the first-run wizard end to end, Getting Started's setup states, and the hotkey practice drill (F19);
   - History (list, detail, Copy, Export Pair, Delete, the empty state), Custom Dictionary (add, edit, delete, the empty state), Stats, Voice Engine (no model delete), File Transcription with a short file made by `say -o`, Command Mode's not-ready banner, AI Enhancement (look only), Feedback (no submit), and the status menu;
   - dictation end to end: in the Debug build's own microphone setting pick **BlackHole 2ch**, open a new TextEdit document, and before every `toggleDictation` confirm with System Events that TextEdit is frontmost (otherwise skip that attempt: the text would land in an agent's terminal and be sent). Speak with `say -a "BlackHole 2ch" "<a neutral sentence>"` and check the text in TextEdit. Never change the system's default input or output device, or the installed app's settings;
   - window resizing to the 800 × 500 minimum and wide; nothing jumps between states.

   Its tools: the repo's Debug triggers (CLAUDE.md, Validate: `toggleDictation`, `cancelDictation`, `logOverlayTargets`), `cliclick` (it cannot press F18 or F19; use the `osascript` key codes), `screencapture`, and AppleScript / System Events. It writes `datasheet-run/QA.md` with a screenshot per finding and mails you. You turn each real bug into a fix PR through the gate, then have the QA seat re-check those items.

## Hard rules

- Nothing disappears except the Accent Color picker. Where `main` changed after the prototype, `main` wins: PR #57 removed "Allow in c11" (the prototype still draws it; don't build it) and added Q for Question Mark. States and controls the prototype never drew still ship, styled in Datasheet Mono (BUILDPLAN rule 2: permission recovery, conflicting copies, Relaunch, recording-disabled settings, model download states, the regional filler offer, the overlay mic picker, Q for Question Mark).
- The live overlay, the menu bar mark and text delivery stay untouched, apart from phase 0's mechanical rename and lane F's two status menu additions. Delivery into c11 and Ghostty must never regress.
- Tokens only from `DatasheetTheme` (`SignalTheme` until phase 0's rename); reuse the existing primitives; no layout jumps.
- No release, no tag, no install, no change to `/Applications`. Merging to `main` is the furthest any change goes.
- Fast mode only where Atin named it: Luna seats, through "Luna Fast Max". You and Astra run at standard speed.

## Reporting

Keep your panel's description current (what is merged, what is in flight). When the run ends, write the morning report as a local HTML page in Datasheet Mono, `~/Projects/MouthKeys-worktrees/datasheet-run/report.html`, open it in a c11 browser panel, then stop the utility processes and close finished panels. The report opens with "Needs you:" and numbered questions, each saying what hangs on it, then: merged PRs, what the walkthrough and QA found and what was fixed, what was not exercised and why, what is left with a reason, and the install handoff for Atin (the Developer ID path in `docs/INSTALL-CHECKLIST.md`; he installs).
