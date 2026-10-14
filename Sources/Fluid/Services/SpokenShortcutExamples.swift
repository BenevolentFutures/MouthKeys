import Foundation

// The "say this, get this" rows under Settings > Spoken Shortcuts. Each row's result comes from
// running the real Spoken Send parser and Q shortcut on what is said, so the examples stay true
// for the user's own send phrase and literal word. `SpokenShortcutExamplesTests` pins them for
// the defaults.

nonisolated struct SpokenShortcutExample: Equatable, Sendable, Identifiable {
    /// What the user says.
    let said: String
    /// What MouthKeys types. Empty when nothing is typed.
    let typed: String
    /// Whether the send key follows.
    let sends: Bool
    /// The text goes to a terminal (c11, Ghostty, Terminal): no sentence ending is added.
    let inTerminal: Bool

    var id: String { "\(self.said)|\(self.inTerminal)" }
}

nonisolated enum SpokenShortcutExamples {
    /// The word that types the send phrase instead of sending. `SpokenSendParser` matches it
    /// as written, whatever the Start Word in Custom Dictionary is; Q uses the Start Word.
    static let sendLiteralWord = "literal"

    static func questionMark(literalPrefix: String) -> [SpokenShortcutExample] {
        let prefix = literalPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "is it green Q",
            "is it green QQ and then what",
            "press \(prefix) Q",
            "add it to the queue",
        ].map { said in
            SpokenShortcutExample(
                said: said,
                typed: QuestionMarkShortcut.apply(said, literalPrefix: prefix),
                sends: false,
                inTerminal: false
            )
        }
    }

    static func spokenSend(phrase: String) -> [SpokenShortcutExample] {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let cases: [(said: String, inTerminal: Bool)] = [
            ("fix the typo \(phrase)", false),
            ("fix the typo \(phrase)", true),
            (phrase, false),
            ("I'll \(phrase) tomorrow", false),
            ("can you \(phrase)", false),
            ("\(self.sendLiteralWord) \(phrase)", false),
        ]
        return cases.map { said, inTerminal in
            let result = SpokenSendParser.parse(said, phrase: phrase, enabled: true, forTerminal: inTerminal)
            return SpokenShortcutExample(said: said, typed: result.text, sends: result.shouldSend, inTerminal: inTerminal)
        }
    }
}
