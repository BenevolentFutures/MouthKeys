# MouthKeys app: Signal

**Status: design exploration, round 1 (2026-10-02). Not reviewed by Atin.** No Swift was touched.

Prototype: [`index.html`](index.html), self-contained (double-click, or `./serve.sh` for Safari, which renders SF Mono). Screenshots of every screen in both themes: [`shots/`](shots/), regenerated with `python3 shoot.py` (headless WebKit, nothing on screen).

Keys: **T** toggles dark and light (the page follows `prefers-color-scheme` until you press it), **O** opens the first-run wizard (arrows step through it), **1–0** jump to the ten sidebar screens, **Esc** closes menus. The menu bar mark (top right) opens the status menu. Press **Start Recording** on Getting Started to drive the overlay reference.

## Thesis, applied to the window

The overlay is an engineering drawing of an instrument. The window is the same drawing set: the sidebar is the margin with its zone index, each screen is a sheet with a title block, each section a zone label with a rule running to the edge, each settings group a ruled table. Square solid surfaces, 1 px rules, no radius, no gradient, no blur except the one float shadow under windows (the overlay's `float-shadow`). Mono uppercase for every label, count and number; SF Pro for anything read as prose. International orange only for something live or actionable right now: the record button, a download in progress, a step that needs you, a NOT PASTED marker, a destructive confirm. State is otherwise carried by inversion and by words with a square: filled ink (done), filled orange (live or needs you), outline (absent).

Tokens are DESIGN.md §2 copied verbatim into CSS variables. Five window-only tokens are added and named in the CSS: `desk` (stage only), `rule` (= edge), `rule-soft` (row hairlines), `sidebar` and `field` (one step below surface).

## The bracket rule

Brackets are the overlay's: four L marks outside the corners, 1.5 pt stroke on a 1 pt surface halo, never orange, 60 ms fade, no layout effect. The window adds one tier at rest:

1. **At rest:** the screen's primary action, and the chosen card in a choice set. At most one primary per panel (Getting Started's next setup step, the playground's record button, Copy in a history entry, the wizard's Continue). At-rest brackets draw at 62% and go to full on hover, so hover still answers the pointer.
2. **On hover:** every other clickable control: secondary and text buttons, segmented controls, pickers, toggles (around the switch only), hotkey wells, fields, tags, overlay chips.
3. **Never:** rows. Sidebar, tables, lists, menus, titlebar cells and the settings zone strip invert instead, as the overlay's history card does.

A screen with no single action (Settings saves as you go) has no at-rest bracket. That is the point: a bracket at rest means "this is the move".

## Layout grid

- Window 1120 × 760 in the prototype (the app's default is 1000 × 700, minimum 800 × 500; everything reflows). Titlebar 40, sidebar 240 (inside the app's 220–300).
- Content: 40 pt side padding, 880 max width, 8 pt rhythm. Title block: mono placard, 28/32 semibold title, 14/20 lede, rule. Sections 34 apart.
- Settings rows: 60 pt minimum, label 14/19 medium, help 13/18, control right-aligned. Dependent rows indent 22 with a drawn leader.
- Type floor: 10 pt mono uppercase, 13 pt prose. Every number is mono, so tabular by construction. Toggles (74 wide with a reserved ON/OFF word), segments (fixed cell widths) and readouts (fixed character boxes) never change size.

## Screens

Main window, sidebar order and names as `ContentView.swift`:

| # | Section | Screen | What changed |
|---|---|---|---|
| 01 | Configure | Settings | One sheet, ten lettered zones (App, Hotkeys, Dictation, History, Format, Alerts, Audio, Overlay, Backup, Debug) with a sticky zone strip. Microphone permission folds into Audio. |
| 02 | Configure | Voice Engine | Preview panel with a spec strip (size, languages, speed and accuracy as 10-cell meters), then the model table. Filler words as tags. |
| 03 | Configure | Custom Dictionary | Teach Words (voice / manual) with a 3-cell readiness meter; the dictionary, spoken formatting and custom words shown inline as tables instead of popovers. |
| 04 | Use | Command Mode | Not-ready banner (it needs an AI Enhancement provider), chat with an orange-ruled confirm panel; Empty / Sample toggle in the prototype. |
| 05 | Use | File Transcription | Drop zone, then file options, progress, speaker-labelled result; recent table. Header now matches the sidebar ("File Transcription", was "Meeting Transcription"). |
| 06 | Activity | History | Full-bleed list and detail: overlay-style index column, NOT PASTED marker, a title-block strip of facts, large reading text. Empty state included. |
| 07 | Activity | Stats | Four KPI cells, words-per-day bars (today in orange), milestone grid, insights and records tables. |
| 08 | Advanced | AI Enhancement | Alone under Advanced, opening with the unsupported note verbatim. Providers and Advanced Prompts as tabs. |
| 09 | Help | Getting Started | Quick Setup as four numbered steps, the playground, the round 6 overlay pill live beside it, How to Use. |
| 10 | Help | Feedback | Text, version toggle, Open GitHub Issue; the FluidVoice credit. |

Also: the first-run wizard (Welcome, Language, Voice Engine, Enable Access, Try MouthKeys, ending in Finish Setup) as the window's first state with a step rail, the status menu with its microphone submenu, the titlebar (Today, Theme, Report) and a hotkey capture state.

## Native mapping

| Component | SwiftUI / AppKit | Cost |
|---|---|---|
| Bracket (`.tk`) | The overlay's `Bracket: Shape`, reused. A `SignalBracketed` modifier with `rest: Bool`; opacity 0.62 at rest, 1 on `.onHover`. | Small: exists |
| Window | `NavigationSplitView` keeps its structure; `.windowStyle(.hiddenTitleBar)` plus our own 40 pt title strip; sidebar `List` replaced by a `ScrollView` of `SignalNavRow` (a `Button` with an inverted selected style). Traffic lights stay the system's. | Medium |
| Title block, section rule | `SignalSheetHeader` and `SignalSection` views: a mono `Text` placard, title, and a `Rectangle().frame(height: 1)`. | Small |
| Settings row | `SignalRow(label:help:) { control }`, an `HStack` with a 1 px bottom rule; `.indent` adds the leader `Path`. Replaces `Form`/`GroupBox`. | Small |
| Zone strip | `ScrollViewReader` + a pinned header (`LazyVStack(pinnedViews: .sectionHeaders)`); cells `scrollTo` their zone. | Small |
| Toggle | A custom `ToggleStyle`: 40 × 20 `Rectangle`, 12 pt square knob, fixed-width mono ON/OFF. | Small |
| Segmented | A custom `Picker` rendering: `HStack(spacing: 0)` of fixed-width cells, selected cell `inv-bg`. Not `.pickerStyle(.segmented)`, which forces radius. | Small |
| Picker | `Menu` with a custom label (field box plus chevron); `NSMenu` styling stays the system's, header rows as disabled mono items, as the status menu does today. | Small |
| Slider | Custom: a `GeometryReader` track, `DragGesture` thumb, graticule `Canvas`, fixed-width mono readout. | Medium |
| Hotkey well | Wraps the existing shortcut recorder; cap views are mono `Text` in a 1 px box; capture state swaps to the orange square and "Press shortcut…". | Small |
| Tables (models, dictionary, devices, history) | `LazyVStack` of row `Button`s with hover and selection inversion; headers are mono rows. Not `Table`, whose chrome cannot be squared. | Medium |
| Meters, readiness, milestones | Plain `HStack`s of `Rectangle`s. | Small |
| Stats chart | Swift Charts `BarMark` with square ends, no gradient, today in `accent`; or a `Canvas`. | Small |
| Empty state | A `Canvas` grid background with a ruled card on top. | Small |
| Overlay reference in the playground | Host the real `SignalOverlay` view inline, driven by the playground recording. | Small |
| Wizard | `OnboardingFlowView` keeps its steps; the backdrop glow and cards are replaced by the step rail, a ruled content area and the ruled footer. | Medium |

## Decisions to react to

1. **Accent colour picker removed** from Settings (Cyan, Green, Blue, Purple, Orange). Signal has one colour; a picker contradicts it. Assumption, not ruled.
2. **Edit Mode and Command Mode guidance dropped from Getting Started**: both need an AI provider, which setup no longer asks for. Command Mode keeps its own screen with a not-ready banner.
3. **Popovers became inline tables** in Custom Dictionary, so the words you taught are visible without a click.
4. **History detail shows delivery** (Pasted / NOT PASTED) to match the overlay card; the app's AI Processed field moves into the details line.
5. **The wizard is the window's first state**, drawn as a step rail, not a cinematic backdrop with a mouse-following glow.

## Unsure

- Command Mode's honest state for a straight-dictation user is "not ready". The sample chat is shown so the confirm panel can be judged.
- Sound cue names (Liquid SFX 0–4) and the AI Prompt picker are kept as they are.
- Stats figures, the app version string and the file-transcription transcript are invented for realism.
