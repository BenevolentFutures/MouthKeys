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

**Read first, in order:**
1. `CLAUDE.md`. Its rules bind every agent you launch: never touch `/Applications/MouthKeys.app` or its data, never install or release, keep the XCTest host invisible and silent, full suites on Atlas.
2. `design/visual-language/DESIGN.md`, the locked Datasheet Mono tokens.
3. `design/app-signal/DIRECTION.md`: thesis, bracket rule, layout grid, screen table, native mapping, decisions on record.
4. `design/app-signal/BUILDPLAN.md`: ground rules, where things live, phases, validation loop, parity checklist, risks, and the decisions Atin settled on 2026-10-07. It is the contract; follow it, and don't reopen a settled decision.
5. The prototype itself. Serve it with `PORT=8767 design/app-signal/serve.sh` (8766 is often held by the visual-language prototypes server, which serves a different folder and returns 404 here) and open it in a c11 browser tab. Keys: T theme, O wizard, S setup state, 0 to 9 screens (prototype navigation only; the app gets no screen-jump shortcuts). Screenshots of every screen in both themes are in `design/app-signal/shots/`.

The design files live on `origin/design/app-signal`, not on `main`; read them there (`git show origin/design/app-signal:<path>`, or the worktree at `~/Projects/MouthKeys-worktrees/app-signal`).

**Branching.** Start from `origin/main`. Work on `feature/datasheet-window` and one branch per lane off it, or off `main` after phases 0 and 1 merge. Bring `design/app-signal/` into the first PR so the reference lives in the repo. PRs go to `--repo BenevolentFutures/MouthKeys --base main`.

**Before the first seat.**
- Load the `c11` skill, run `c11 conversation capture-runtime`, and name your panel "MouthKeys build". Set `mailbox.address` to `mk-build-sol` and `mailbox.delivery` to `stdin`, so a seat's mail wakes you.
- Keep Hyperion's display awake for the whole run: start `caffeinate -d -i -m` in the background and record its PID. With the display asleep, new c11 panels come up dead and screen checks fail.
- Start a heartbeat: a background loop that runs `c11 mailbox send --to mk-build-sol --body tick` every 20 minutes, PID recorded. Seats mail you on events, but a seat that dies says nothing, and the tick is what catches it.
- Kill both PIDs when the run ends.

**Seats.**
- **Implementers: Luna.** One seat per phase or lane, each in its own git worktree under `~/Projects/MouthKeys-worktrees/`, never the main checkout: `c11 config launch "Luna Fast Max" --workspace <yours> --cwd <its worktree> --prompt-file <brief> --json`. After each launch, read its status line: it must say `GPT-6-Luna max fast` (the startup warning that `-c` overrides need embedded mode is expected). Never send `/fast`, `/ultrafast` or `/model` to any seat, and never edit `~/.codex/config.toml`: it is shared, and a change there reaches every new Codex session on the machine.
- **Briefs.** Write each brief to a file; never put prose in a shell argument. It carries the seat's phase section of `BUILDPLAN.md`, the files it owns, the ground rules, the validation loop, its parity checklist duty, the hard rules below, and its first steps: load the `c11` skill, run `c11 conversation capture-runtime`, name its panel (2 to 4 words, lane first). It reports with `c11 mailbox send --to mk-build-sol --body "<one line>"` when its PR opens, when it is blocked, and when it is done.
- **Reviews.** Every PR gets a fresh-context review by an Astra seat: `c11 config launch "Astra XHigh" --workspace <yours> --cwd <a disposable review worktree at the PR head> --prompt-file <review brief>`. It reviews against the prototype, `shots/`, `BUILDPLAN.md` and the parity checklist, and returns numbered findings. Findings go back to the owning Luna seat. Close each Astra seat when its review is in.
- **Re-dispatch.** A Luna seat that fails two review rounds, or repeats the same failed assumption, hands its lane to a fresh Sol seat ("Sol High") at its next clean pushed boundary.
- **Stalls.** On every tick, check each seat (`c11 tree`, the tail of `c11 read-screen`, its branch and PR). A seat with no progress for 45 minutes gets one nudge with `c11 send`; still stuck 20 minutes later, close it and relaunch its lane from its last pushed commit.
- **Limits.** If Codex hits a usage limit, stop every seat at a clean pushed boundary and record where the run stands. Nothing moves outside Codex.
- **Housekeeping.** Close each seat's panel and remove its worktree once its PR is merged and nothing else needs it.

**Sequence.**
1. Phase 0 (foundations), then phase 1 (window chrome): one Luna seat each, in order; phase 1 starts after phase 0 merges.
2. Then lanes 2 to 6 in parallel, one Luna seat each. Lanes touch only their own `detailContent` case in `ContentView.swift`. Lane A (Settings) writes `design/app-signal/PARITY.md` first; the other lanes add their rows to it.
3. **Merge gate (you, as Merge Captain).** A PR merges when the Astra review has no open blocking finding, the full suite is green on Atlas at the PR's exact head, its offscreen renders match `shots/` or the difference is explained by the parity checklist or BUILDPLAN rule 2, and it is rebased on current `main`. Merge one PR at a time with `gh pr merge --merge`. Split polish into follow-up PRs rather than holding a merge.
4. Walkthrough: one Debug build of `main`, every screen in both themes, the wizard and the status menu, against the prototype. Hand what differs to Luna seats as fix PRs, through the same gate.
5. **QA round (Luna).** Once everything is merged, launch one fresh Luna seat on current `main` to test the app as thoroughly as it can, as a user would, in the Debug build (`MouthKeys Debug.app`, `.dev` identity, its own data and permissions):
   - every sidebar screen in both themes, and the theme switch itself;
   - every Settings control: change it, confirm it takes effect, relaunch the Debug build, and confirm it persisted; check against `PARITY.md` that no control went missing;
   - the first-run wizard end to end, Getting Started's setup states and the hotkey practice drill;
   - History (list, detail, Copy, Export Pair, Delete, the empty state), Custom Dictionary (add, edit, delete, the empty state), Stats, Voice Engine, File Transcription with a short audio file it makes with `say -o`, Command Mode's not-ready banner, AI Enhancement, Feedback, and the status menu;
   - dictation end to end: in the Debug build's own microphone setting pick **BlackHole 2ch**, play speech into it with `say -a "BlackHole 2ch" "<phrase>"`, and check the text lands in a TextEdit document. Never change the system's default input or output device, or the installed app's settings;
   - window resizing to the 800 × 500 minimum and wide; no element jumps between states.
   Its tools: the repo's scripted Debug triggers (CLAUDE.md, Validate: `toggleDictation`, `cancelDictation`, `logOverlayTargets`), `cliclick` for real clicks, `screencapture` for evidence, and AppleScript / System Events for menus and windows. It writes a QA report with a screenshot per finding and mails you. You turn each real bug into a fix PR (a Luna seat, the same gate), then have the QA seat re-check those items.
6. Add the real-path checks to `docs/INSTALL-CHECKLIST.md`.

**Hard rules.**
- Nothing disappears except the Accent Color picker. Where `main` changed after the prototype, `main` wins: PR #57 removed "Allow in c11" (the prototype still draws it; don't build it) and added Q for Question Mark. States and controls the prototype never drew still ship, styled in Datasheet Mono (BUILDPLAN rule 2: permission recovery, conflicting copies, Relaunch, recording-disabled settings, model download states, the regional filler offer, the overlay mic picker, Q for Question Mark).
- The live overlay, the menu bar mark and text delivery stay untouched. Delivery into c11 and Ghostty must never regress.
- Tokens only from `DatasheetTheme` (`SignalTheme` until phase 0's rename); reuse the existing primitives; no layout jumps.
- One agent at a time drives the screen with a Debug build; you hand out that turn. Its shortcuts are first moved off Atin's keys (CLAUDE.md, Validate). Confine it to a verified display, quit the Debug build when done, and never touch the installed app. Anything that could quit the installed app waits for an idle dictation log.
- Heavy work goes to Atlas: full suites, cold builds, batch renders. Hyperion runs only incremental builds and single test suites, and at most two `xcodebuild` processes at once across all seats.
- No release, no tag, no install, no change to `/Applications`. Merging to `main` is the furthest any change goes.
- Fast mode only where Atin named it: Luna seats, through "Luna Fast Max". You and Astra run at standard speed.

**Reporting.** Keep your panel's description current (what is merged, what is in flight). At every merge, and at every decision you made in Atin's place, append one line to `~/Projects/MouthKeys-worktrees/datasheet-run-log.md`: time, PR or decision, the review result and the suite result. When the run ends, write the morning report as a local HTML page in Datasheet Mono, `~/Projects/MouthKeys-worktrees/datasheet-run-report.html`, and open it in a c11 browser panel. It opens with "Needs you:" and numbered questions (each saying what hangs on it), then: merged PRs, what the walkthrough and QA found and what was fixed, what is left with a reason, and the install handoff for Atin (the Developer ID path in `docs/INSTALL-CHECKLIST.md`; he installs).
