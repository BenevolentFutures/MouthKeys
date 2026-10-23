# MouthKeys

<p align="center"><b><i>Wicked fast voice to text for macOS: no frills, just function, well designed</i></b></p>

<p align="center"><img src="docs/images/overlay.png" width="560" alt="The MouthKeys overlay mid-dictation: the live transcript above a voice trace, a 13-second timer, 43 words and 203 words per minute in the foot row, and the active mic. History and copy sit on the left rail, cancel and reprocess on the right."></p>

<p align="center"><samp>mid-dictation: the live transcript, your voice as a trace, and the word count and words per minute as you speak.</samp></p>

<p align="center"><a href="https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/MouthKeys.dmg"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/download-dark.svg"><img src="docs/images/download-light.svg" width="280" height="56" alt="Download MouthKeys.dmg"></picture></a></p>

<p align="center"><samp>free and open source · macOS 15 or later · made for Apple Silicon<br><a href="https://mouthkeys.com">mouthkeys.com</a> · <a href="docs/BUILDING.md">build from source</a></samp></p>

---

listen.

you talk to your computer all day now. prompts for agents, replies, notes. dictation should be the fastest way in, but it fails quietly. the text lands in the wrong window. a terminal swallows it. the clipboard you were holding is gone. you find out when you look up.

the problem is not hearing you. the problem is. delivery.

**MouthKeys is on-device dictation for macOS.** hold or tap a hotkey, speak, and the text lands where you were typing when you stopped. the speech model runs on your Mac: Parakeet, Nemotron, Cohere Transcribe, Whisper or Apple Speech. no account, no telemetry, no subscription. when it sees a paste fail, it tells you and puts the words on your clipboard.

## what you get.

- **paste you can trust.** when a paste fails in a way the app can detect, a card shows, and the text goes on your clipboard unless you copied something since. your own clipboard comes back, images and files included. back-to-back dictations queue instead of dropping.
- **a fast stop.** outside the speech model, stopping takes about 4 ms. a stalled model never loses the recording: it is kept for Reprocess, even across a restart.
- **built for terminals.** Ghostty and [c11](https://github.com/Stage-11-Agentics/c11), Stage 11's terminal multiplexer, always get Reliable Paste.
- **Spoken Send.** end with "send it" (or any phrase you pick, like "send send") and Return follows the text half a second later, in every app, only into the pane or field you stopped in. off by default.
- **Q for a question mark.** end with "Q", or say "Q Q" anywhere, and it types "?". off by default.
- **a live voice trace.** a scrolling trace of your voice, calibrated to the recording, so you can see it hearing you.
- **live counters.** a timer, a word count and words per minute while you speak.
- **your mic at a glance.** the active mic shows in the overlay, with the battery level of a Hollyland lapel mic.
- **a history browser.** recent dictations, each one click from copy or reprocess. drag the overlay anywhere.
- **an interface that stays quiet.** the overlay, history, cards, menu bar and icon share one visual language, Datasheet Mono: square, flat, monochrome, with orange marking only what is live. copy, reprocess, cancel and history sit one click away on a slim rail beside the pill, and nothing on screen moves unless it means something. [design notes](design/visual-language/DESIGN.md)
- **hotkeys and mics that behave.** holds that always end, removed mics that stay removed, media resumed only if MouthKeys paused it, a hung mic routed around, and a hotkey to reprocess the last dictation.

<p align="center"><img src="docs/images/history.png" width="520" alt="The MouthKeys history browser open directly above the recording overlay: recent dictations newest first, each with its time, word count and destination app. Below it, the overlay is mid-dictation with its live transcript, voice trace, timer and counters."></p>

<p align="center"><samp>the history browser opens right where you are, above the overlay. click a dictation to insert it again.</samp></p>

## install.

1. **[download MouthKeys.dmg](https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/MouthKeys.dmg)**.
2. open it and drag MouthKeys to Applications.
3. open MouthKeys. it asks for the Microphone, to hear you, and Accessibility, to type into other apps, then for a speech model; the default, Parakeet TDT v3, is about a 460 MiB download.

no clone, no Xcode, nothing to build. the app is signed with a Developer ID and notarized by Apple, so it opens like any other app.

it runs on macOS 15 or later. Parakeet, Nemotron and Cohere, the default engines, need Apple Silicon. Apple Speech needs macOS 26. Whisper and Apple ASR Legacy also run on Intel, untested.

**updating.** download the new DMG and drag MouthKeys over the old one. your settings, dictionary, history and permissions stay.

**building it yourself.** the code is all here, and [docs/BUILDING.md](docs/BUILDING.md) walks you through it.

**coming from FluidVoice.** MouthKeys brings your settings, dictionary and history over on its first launch; [docs/FLUIDVOICE.md](docs/FLUIDVOICE.md#coming-from-fluidvoice) has the details.

## privacy.

no telemetry, no account. your audio and your text stay on your Mac unless you choose otherwise. the app goes online for three things, each your choice:

- downloading the speech model you pick.
- AI cleanup, if you set up a provider: OpenAI, Anthropic, Google, xAI, Groq, Cerebras, OpenRouter or a custom endpoint. Ollama and LM Studio stay on your Mac.
- **Apple ASR Legacy**, which lets macOS choose where speech is recognized, and that may be Apple's servers. every other engine runs on the Mac.

Feedback opens a draft GitHub issue in your browser. the app posts nothing; you read it and submit it yourself.

## built on FluidVoice.

MouthKeys began as a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) by altic-dev, which did the hard part: the speech pipeline, the model integrations, the hotkeys and typing into other apps. FluidVoice grew in many directions at once. MouthKeys does one job: every word lands where you were typing.

- **open source, all of it.** FluidVoice's AI layer, Fluid Intelligence, is maintained privately, outside its open-source code. MouthKeys leaves it out.
- **nothing phones home.** no analytics, no usage signals, nothing sent to FluidVoice's servers.
- **delivery first.** paste failures caught and recovered, your clipboard given back, a stop path rebuilt to take about 4 ms outside the model, and terminals treated as first-class.
- **quiet by design.** one visual language, and nothing on screen moves unless it means something.

what changed, what we left out, and how we follow FluidVoice's work: [docs/FLUIDVOICE.md](docs/FLUIDVOICE.md). if you want FluidVoice's AI features, FluidVoice is the app for that.

## contributing.

bugs and ideas go in [issues](https://github.com/BenevolentFutures/MouthKeys/issues). pull requests target `main`; start with [CONTRIBUTING.md](CONTRIBUTING.md).

## license.

MouthKeys is free software under the GPL-3.0, the license FluidVoice gave it. use it, study it, change it and share it, and what you share stays just as free. the terms are in [LICENSE](LICENSE); what we changed, and whom we owe, is in [NOTICE.md](NOTICE.md).

---

<p align="center"><i>your voice is the fastest way to get a thought out of your head. it should land where you meant it.</i></p>
