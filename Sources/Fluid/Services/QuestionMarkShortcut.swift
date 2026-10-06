import Foundation

// "Q" for a question mark. Transcribers often miss that a sentence was a question, and "question
// mark" is two words behind the literal prefix; a spoken Q is one. "Q Q" anywhere (also "QQ",
// "Q. Q.", "queue queue", "cue cue") types "?", and so does a "Q" or "cue" that ends the dictation.
// "<literal prefix> Q" types the letter.
//
// Runs once, on the final text, after Spoken Send has taken its phrase off: "Is that right Q send
// it" types "Is that right?" and sends. Not idempotent ("literal Q" becomes "Q"), so it never runs
// inside `applySpokenPunctuationFormatting`, which a transcript passes through twice.

nonisolated enum QuestionMarkShortcut {
    /// Applies the shortcut when it is turned on in Settings.
    @MainActor
    static func apply(_ text: String, settings: SettingsStore = .shared) -> String {
        guard settings.questionMarkShortcutEnabled else { return text }
        return self.apply(text, literalPrefix: settings.punctuationDictionaryPrefix)
    }

    static func apply(_ text: String, literalPrefix: String) -> String {
        let literalRegex = self.literalRegex(for: literalPrefix)
        let doubled = self.replacingDoubled(in: text, literalRegex: literalRegex)
        // "literal Q Q" at the end keeps both letters: the last one is not a trailing Q.
        guard !doubled.endsLiteral else { return doubled.text }
        return self.replacingTrailing(in: doubled.text, literalRegex: literalRegex)
    }

    /// Two Qs in a row, anywhere. A real word never starts or ends inside the match ("Q3", "IQ").
    private static let doubledRegex = try? NSRegularExpression(
        pattern: #"(?i)(?<![\p{L}\p{N}_'’])(?:qq|(?:q|queue|cue)[\s.,;:!?-]+(?:q|queue|cue))(?![\p{L}\p{N}_'’])"#
    )

    /// A Q or "cue" that ends the text, with any punctuation the transcriber put after it.
    /// Not "queue": "Add it to the queue" ends a real sentence.
    private static let trailingRegex = try? NSRegularExpression(
        pattern: #"(?i)(?<![\p{L}\p{N}_'’])(?:q|cue)[\s.,;:!?]*$"#
    )

    /// Punctuation the transcriber put where the question mark goes.
    private static let replacedEndings: Set<Character> = [",", ".", ";", ":", "!", "…"]

    private static func replacingDoubled(in text: String, literalRegex: NSRegularExpression?) -> (text: String, endsLiteral: Bool) {
        guard let doubledRegex else { return (text, false) }
        var output = ""
        var rest = text
        var endsLiteral = false
        while let match = doubledRegex.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
              let range = Range(match.range, in: rest)
        {
            let before = String(rest[..<range.lowerBound])
            let after = rest[range.upperBound...]
            if let literalStart = self.literalPrefixStart(endingAt: before, literalRegex: literalRegex) {
                output += before[..<literalStart] + rest[range]
                endsLiteral = after.allSatisfy { $0.isWhitespace || $0.isPunctuation }
                rest = String(after)
                continue
            }
            output += self.endingWithQuestionMark(before)
            let next = after
                .drop(while: { self.replacedEndings.contains($0) || $0 == "?" })
                .drop(while: \.isWhitespace)
            guard let first = next.first else {
                rest = ""
                break
            }
            output += " "
            rest = first.uppercased() + next.dropFirst()
        }
        return (output + rest, endsLiteral)
    }

    private static func replacingTrailing(in text: String, literalRegex: NSRegularExpression?) -> String {
        guard let trailingRegex,
              let match = trailingRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text)
        else { return text }
        let before = String(text[..<range.lowerBound])
        if let literalStart = self.literalPrefixStart(endingAt: before, literalRegex: literalRegex) {
            return String(before[..<literalStart] + text[range])
        }
        return self.endingWithQuestionMark(before)
    }

    /// `text` without its trailing space and sentence punctuation, ending in one question mark.
    private static func endingWithQuestionMark(_ text: String) -> String {
        var trimmed = text
        while let last = trimmed.last, last.isWhitespace || self.replacedEndings.contains(last) {
            trimmed.removeLast()
        }
        return trimmed.hasSuffix("?") ? trimmed : trimmed + "?"
    }

    /// The literal prefix, alone at the end of `text` with only spacing or a separator after it.
    private static func literalRegex(for prefix: String) -> NSRegularExpression? {
        let words = prefix.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !words.isEmpty else { return nil }
        return try? NSRegularExpression(
            pattern: #"(?i)(?<![\p{L}\p{N}_])"# + words.joined(separator: #"\s+"#) + #"[\s,:;]*$"#
        )
    }

    /// Where the literal prefix starts, when it is what comes right before the Qs.
    private static func literalPrefixStart(endingAt text: String, literalRegex: NSRegularExpression?) -> String.Index? {
        guard let literalRegex,
              let match = literalRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return Range(match.range, in: text)?.lowerBound
    }
}
