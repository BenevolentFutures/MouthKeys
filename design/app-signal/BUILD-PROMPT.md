# Build prompt: MouthKeys Datasheet Mono window

**Who runs it** (Atin, 2026-10-07): Codex on Sol (`gpt-6.1-sol`) at high effort orchestrates; Grok Build seats on `grok-4.7` at high effort do all the implementation. Ready to start: every open question was answered on 2026-10-07 (`BUILDPLAN.md`, "Decided with Atin") and `design/app-signal` is pushed.

Launch the orchestrator from any c11 shell. Use the newest Sol in Codex `/model` if one has shipped since (never an older one):

```bash
c11 launch-agent --type codex --model gpt-6.1-sol --effort high \
  --cwd ~/Projects/MouthKeys --title "MouthKeys build" \
  --prompt "Read /Users/atin/Projects/MouthKeys-worktrees/app-signal/design/app-signal/BUILD-PROMPT.md and follow everything below its line."
```

Then read the new tab's status line: it must say Sol at high with no "fast" (`~/.claude/references/launching-agents.md`).

---

You are orchestrating the approved Datasheet Mono redesign of the MouthKeys main window: a pure restyle of the SwiftUI app to match an HTML prototype, one to one, with no behavior change. You run on Sol. You brief, review, gate and merge; Grok seats write the product code, every phase and every lane. This run is loopy: implement, validate, iterate, report.

**Read first, in order:**
1. `CLAUDE.md`. Its rules bind every agent you launch: never touch `/Applications/MouthKeys.app` or its data, never install or release, keep the XCTest host invisible and silent, full suites on Atlas.
2. `design/visual-language/DESIGN.md`, the locked Datasheet Mono tokens.
3. `design/app-signal/DIRECTION.md`: thesis, bracket rule, layout grid, screen table, native mapping, decisions on record.
4. `design/app-signal/BUILDPLAN.md`: ground rules, where things live, phases, validation loop, parity checklist, risks, and the decisions Atin settled on 2026-10-07. It is the contract; follow it, and don't reopen a settled decision.
5. The prototype itself. Serve it with `PORT=8767 design/app-signal/serve.sh` (8766 is often held by the visual-language prototypes server, which serves a different folder and returns 404 here) and open it in a c11 browser tab. Keys: T theme, O wizard, S setup state, 0 to 9 screens (prototype navigation only; the app gets no screen-jump shortcuts). Screenshots of every screen in both themes are in `design/app-signal/shots/`.

The design files live on `origin/design/app-signal`, not on `main`; read them there (`git show origin/design/app-signal:<path>`, or the worktree at `~/Projects/MouthKeys-worktrees/app-signal`).

**Branching.** Start from `origin/main`. Work on `feature/datasheet-window` and one branch per lane off it, or off `main` after phases 0 and 1 merge. Bring `design/app-signal/` into the first PR so the reference lives in the repo. PRs go to `--repo BenevolentFutures/MouthKeys --base main`.

**Seats.** Load the `c11` skill first; set your own `mailbox.address` so seats can report to you.
- **Implementers: Grok.** One Grok Build seat per phase or lane, launched with `c11 launch-agent --type grok --model grok-4.7 --cwd <its worktree> --title "<lane, 2 to 4 words>" --prompt-file <brief>`. Always pass `--model grok-4.7`: Grok's own default is `grok-4.7-build-fast`, and no seat runs a fast model. c11's Grok launcher takes no `--effort` (it errors); high effort comes from `default_reasoning_effort = "high"` in `~/.grok/config.toml`, so check that line before the first launch. Each seat gets its own git worktree under `~/Projects/MouthKeys-worktrees/`, never the main checkout: Grok's permission modes do not stop file writes.
- **Briefs.** Write each brief to a file; never put prose in a shell argument. It carries the seat's phase section of `BUILDPLAN.md`, the files it owns, the ground rules, the validation loop, its parity checklist duty, the hard rules below, and how to report: `c11 mailbox send` to you when its PR opens, when it is blocked, and when it is done. Grok has the `c11` skills installed; tell it to load `c11`.
- **Reviews.** Every PR gets a fresh-context review from another family than Grok: Astra (`gpt-6-astra`, xhigh) by default, Opus (Claude Code, high) when Astra is unavailable. Findings go back to the owning Grok seat to fix.
- **Re-dispatch.** A Grok seat that fails two review rounds, or repeats the same failed assumption, hands its lane to Astra at its next clean pushed boundary. Say so in the next status.
- **Limits.** Grok runs on Atin's SuperHeavy plan; use it to the limit. If a seat hits a limit, stop it at a clean pushed boundary, move the lane to Astra, and report it.

**Sequence.**
1. Phase 0 (foundations), then phase 1 (window chrome): one Grok seat each, in order; phase 1 starts after phase 0 merges. Each is one PR: fresh-context review, full suite on Atlas, merge.
2. Then lanes 2 to 6 in parallel, one Grok seat each. Lanes touch only their own `detailContent` case in `ContentView.swift`. Lane A (Settings) writes `design/app-signal/PARITY.md` first; the other lanes add their rows to it.
3. Each lane opens a PR. You get it reviewed, run the full suite on Atlas, compare its offscreen renders with `shots/`, and merge. Split polish into follow-up PRs rather than holding a merge.
4. Last: one Debug-build walkthrough of every screen in both themes, the wizard and the status menu, against the prototype. Hand what differs to Grok seats as fix PRs. Add the real-path checks to `docs/INSTALL-CHECKLIST.md`.

**Hard rules.**
- Nothing disappears except the Accent Color picker. Where `main` changed after the prototype, `main` wins: PR #57 removed "Allow in c11" (the prototype still draws it; don't build it) and added Q for Question Mark. States and controls the prototype never drew still ship, styled in Datasheet Mono (BUILDPLAN rule 2: permission recovery, conflicting copies, Relaunch, recording-disabled settings, model download states, the regional filler offer, the overlay mic picker, Q for Question Mark).
- The live overlay, the menu bar mark and text delivery stay untouched. Delivery into c11 and Ghostty must never regress.
- Tokens only from `DatasheetTheme` (`SignalTheme` until phase 0's rename); reuse the existing primitives; no layout jumps.
- One agent at a time drives the screen with a Debug build; you hand out that turn. Its shortcuts are first moved off Atin's keys (CLAUDE.md, Validate). Confine it to a verified display, quit the Debug build when done, and never touch the installed app. Anything that could quit the installed app waits for an idle dictation log.
- Heavy work goes to Atlas: full suites, cold builds, batch renders. Hyperion runs only incremental builds and single test suites.
- No fast mode on any seat: no `/fast` in Codex, no fast Grok model.

**Reporting.** Post a short status at every merge: which phases and lanes are merged, which are in flight and on which seat, what is blocked. Open every report with "Needs you:" and numbered questions. Finish with: merged PRs, the walkthrough result, follow-ups, and the install handoff for Atin (the Developer ID path in `docs/INSTALL-CHECKLIST.md`; he installs).
