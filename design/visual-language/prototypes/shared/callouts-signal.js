// The overlay's parts, named (DESIGN.md §4, §9, §15, §16). Loaded after the Signal overlay is built.
(function () {
  "use strict";
  const firstLine = (el) => (el.innerText || "").trim().split("\n")[0].replace(/^✓\s*/, "").toUpperCase() || "PRIMARY ACTION";
  window.SIGNAL_CALLOUT_ITEMS = [
    { sel: '.sg-chip[data-chip="history"]', label: "History", desc: "Recent dictations · click one to insert" },
    { sel: '.sg-chip[data-chip="copy"]', label: "Copy", desc: "Copy the last transcription" },
    { sel: '.sg-chip[data-chip="cancel"]', label: "Cancel", desc: "Discard this dictation · Esc" },
    { sel: '.sg-chip[data-chip="reprocess"]', label: "Reprocess", desc: "Transcribe the last audio again" },
    { sel: '.sg-chip[data-chip="send"]', label: "Spoken Send", desc: "Click to cancel the Return" },
    { sel: ".sg-preview", label: "Live preview", desc: "The words so far, newest at the end" },
    { sel: ".sg-trace", label: "Voice trace", desc: "12 bars a second of voice · orange head is now" },
    { sel: ".sg-dot", label: "Record square", desc: "Solid: listening · hollow: transcribing" },
    { sel: ".sg-time", label: "Timer", desc: "Length of this dictation" },
    { sel: ".sg-placard", label: "Spoken Send", desc: "SEND: Return follows · NO SEND: it won't" },
    { sel: ".sg-app", label: "Target app", desc: "Where the text will paste" },
    { sel: ".sg-mic", label: "Mic input", desc: "The microphone in use" },
    { sel: ".sg-wc", label: "Word count", desc: "Words in this dictation" },
    { sel: ".sg-wpm", label: "Words per minute", desc: "Your pace, this dictation" },
    { sel: ".sg-stamp", label: "Pasted stamp", desc: "The text was posted to the app" },
    { sel: ".sg-done-head", label: "Outcome", desc: "Where the text went" },
    { sel: ".sg-done-meta", label: "Word count", desc: "Final length" },
    { sel: ".sg-card h3", label: "Problem", desc: "What went wrong" },
    { sel: ".sg-reason", label: "Reason", desc: "Why, and where your text is" },
    { sel: ".sg-card-text", label: "Transcript", desc: "The text that did not land" },
    { sel: ".sg-primary", label: firstLine, desc: "This card's fix" },
    { sel: ".sg-dismiss", label: "Dismiss", desc: "Close the card · it also leaves after 10 s" },
    { sel: ".sg-fail-meta", label: "Word count", desc: "Length of the kept text" },
    { sel: '.sg-textbtn[data-act="reprocess"]', label: "Reprocess", desc: "Transcribe the kept audio" },
    { sel: '.sg-textbtn[data-act="dismiss"]', label: "Dismiss", desc: "Close the notice" },
    { sel: ".sg-notice > b", label: "Notice", desc: "News that needs no rescue" },
    { sel: ".sg-hist header", label: "History card", desc: "Newest first", place: "side", anchor: ".sg-hist" },
    { sel: ".sg-hrow", label: "Dictation", desc: "Click to insert into the focused app", place: "side", anchor: ".sg-hist" },
    { sel: ".sg-flag", label: "Not pasted", desc: "This one never landed", place: "side", anchor: ".sg-hist" },
    { sel: ".sg-hist footer", label: "Title block", desc: "How many, and in what order", place: "side", anchor: ".sg-hist" },
  ];
  window.SignalCallouts.attach({
    anchor: ".sg",
    vars: { surface: "--sg-surface", edge: "--sg-edge", text: "--sg-text", text2: "--sg-text-2", mono: "--sg-mono", font: "--sg-font" },
    items: window.SIGNAL_CALLOUT_ITEMS,
  });
})();
