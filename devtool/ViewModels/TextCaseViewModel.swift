import Foundation

@Observable
class TextCaseViewModel {
    var mode: TextCaseMode { didSet { save("textcase.mode", mode.rawValue); if autoUpdate { transformNow() } } }
    var autoUpdate: Bool { didSet { save("textcase.auto", autoUpdate); if autoUpdate { transformNow() } } }
    var preserveAcronyms: Bool { didSet { save("textcase.acronyms", preserveAcronyms); if autoUpdate { transformNow() } } }
    
    var input: String = "" { didSet { if autoUpdate { transformNow() } } }
    var output: String = ""
    var errorMessage: String?
    
    var statsCharacters: Int = 0
    var statsWords: Int = 0
    var statsLines: Int = 0
    
    init() {
        self.mode = TextCaseMode(rawValue: UserDefaults.standard.string(forKey: "textcase.mode") ?? "") ?? .lower
        self.autoUpdate = Self.loadBoolDefaultTrue("textcase.auto")
        self.preserveAcronyms = Self.loadBoolDefaultTrue("textcase.acronyms")
    }
    
    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }
    private static func loadBoolDefaultTrue(_ key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func transformNow() {
        guard !input.isEmpty else {
            output = ""
            updateStats()
            return
        }
        let locale = Locale.current
        
        switch mode {
        case .lower: output = input.lowercased(with: locale)
        case .upper: output = input.uppercased(with: locale)
        case .sentence: output = toSentenceCase(input, locale: locale)
        case .title: 
            let smallWords = parseSmallWords("a, an, the, and, but, or, for, nor, as, at, by, for, from, in, into, near, of, on, onto, to, with")
            output = toTitleCase(input, locale: locale, smallWords: smallWords, keepAcronyms: preserveAcronyms)
        case .capitalize: output = capitalizeWords(input, locale: locale, keepAcronyms: preserveAcronyms)
        case .inverse: output = inverseCase(input)
        case .alternating: output = alternatingCase(input, startLower: true)
        case .camel: output = toCamelCase(input, locale: locale, keepAcronyms: preserveAcronyms)
        case .pascal: output = toPascalCase(input, locale: locale, keepAcronyms: preserveAcronyms)
        case .snake: output = toSeparatedCase(input, sep: "_", upper: false, locale: locale)
        case .kebab: output = toSeparatedCase(input, sep: "-", upper: false, locale: locale)
        case .constant: output = toSeparatedCase(input, sep: "_", upper: true, locale: locale)
        case .slug: output = toSlug(input, locale: locale)
        }
        
        updateStats()
    }
    
    func clearAll() { input = ""; output = ""; errorMessage = nil; updateStats() }
    
    private func updateStats() {
        let chars = output.count
        let words = output.split { !$0.isLetter && !$0.isNumber }.count
        let lines = output.split(whereSeparator: \.isNewline).count
        statsCharacters = chars
        statsWords = words
        statsLines = max(lines, output.isEmpty ? 0 : 1)
    }
    
    private func parseSmallWords(_ raw: String) -> Set<String> {
        let arr = raw.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Set(arr)
    }
    private func tokenizeWords(_ s: String) -> [String] { s.split { !( $0.isLetter || $0.isNumber ) }.map(String.init) }
    
    private func isAcronym(_ w: String) -> Bool {
        let letters = w.filter { $0.isLetter }
        guard letters.count >= 2 else { return false }
        let upperCount = letters.filter { $0.isUppercase }.count
        return upperCount >= max(2, letters.count - 1)
    }
    
    private func restoreAcronyms(from original: String, into transformed: String) -> String {
        var out = transformed
        for token in tokenizeWords(original) {
            if isAcronym(token) {
                let pattern = NSRegularExpression.escapedPattern(for: token)
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    out = regex.stringByReplacingMatches(in: out, options: [], range: NSRange(out.startIndex..<out.endIndex, in: out), withTemplate: token.uppercased())
                }
            }
        }
        return out
    }
    
    // Core transforms
    private func toSentenceCase(_ s: String, locale: Locale) -> String {
        let separators = CharacterSet(charactersIn: ".!?…")
        var result = ""
        var startOfSentence = true
        for ch in s {
            if startOfSentence {
                if ch.isLetter {
                    result.append(String(ch).uppercased(with: locale))
                    startOfSentence = false
                } else {
                    result.append(ch)
                    if ch.isNewline { startOfSentence = true }
                    continue
                }
            } else {
                result.append(String(ch).lowercased(with: locale))
            }
            if let scalar = ch.unicodeScalars.first, separators.contains(scalar) { startOfSentence = true }
            if ch.isNewline { startOfSentence = true }
        }
        if preserveAcronyms { result = restoreAcronyms(from: s, into: result) }
        return result
    }
    
    private func toTitleCase(_ s: String, locale: Locale, smallWords: Set<String>, keepAcronyms: Bool) -> String {
        let lines = s.components(separatedBy: .newlines)
        let outLines = lines.map { line -> String in
            let tokens = splitByWordBoundaries(line)
            let wordsOnly = tokens.enumerated().filter { $0.element.kind == .word }
            let wordIndices = wordsOnly.map(\.offset)
            var result = tokens
            for (idx, token) in tokens.enumerated() where token.kind == .word {
                let w = token.text
                let isFirst = idx == wordIndices.first
                let isLast = idx == wordIndices.last
                if keepAcronyms, isAcronym(w) {
                    result[idx].text = w.uppercased()
                    continue
                }
                let lower = w.lowercased(with: locale)
                if smallWords.contains(lower), !isFirst, !isLast {
                    result[idx].text = lower
                } else {
                    result[idx].text = capitalizeFirst(lower, locale: locale)
                }
            }
            return result.map(\.text).joined()
        }
        return outLines.joined(separator: "\n")
    }

    private func capitalizeWords(_ s: String, locale: Locale, keepAcronyms: Bool) -> String {
        let tokens = splitByWordBoundaries(s)
        var result = tokens
        for (i, t) in tokens.enumerated() where t.kind == .word {
            if keepAcronyms, isAcronym(t.text) {
                result[i].text = t.text.uppercased()
            } else {
                let lower = t.text.lowercased(with: locale)
                result[i].text = capitalizeFirst(lower, locale: locale)
            }
        }
        return result.map(\.text).joined()
    }

    private func inverseCase(_ s: String) -> String {
        String(s.map { c in
            if c.isLowercase { return Character(c.uppercased()) }
            if c.isUppercase { return Character(c.lowercased()) }
            return c
        })
    }
    private func alternatingCase(_ s: String, startLower: Bool) -> String {
        var makeLower = startLower
        var out = ""
        for ch in s {
            if ch.isLetter {
                out.append(makeLower ? Character(ch.lowercased()) : Character(ch.uppercased()))
                makeLower.toggle()
            } else { out.append(ch) }
        }
        return out
    }
    
    private func toCamelCase(_ s: String, locale: Locale, keepAcronyms: Bool) -> String {
        let words = extractWords(s, locale: locale)
        guard !words.isEmpty else { return "" }
        var result = ""
        for (i, w) in words.enumerated() {
            if i == 0 {
                result += w.lowercased(with: locale)
            } else {
                if keepAcronyms, isAcronym(w) { result += w.uppercased() }
                else { result += capitalizeFirst(w.lowercased(with: locale), locale: locale) }
            }
        }
        return result
    }

    private func toPascalCase(_ s: String, locale: Locale, keepAcronyms: Bool) -> String {
        let words = extractWords(s, locale: locale)
        return words.map { w in
            if keepAcronyms, isAcronym(w) { return w.uppercased() }
            return capitalizeFirst(w.lowercased(with: locale), locale: locale)
        }.joined()
    }

    private func toSeparatedCase(_ s: String, sep: String, upper: Bool, locale: Locale) -> String {
        let words = extractWords(s, locale: locale)
        let mapped = words.map { w -> String in
            if upper { return w.uppercased(with: locale) }
            return w.lowercased(with: locale)
        }
        return mapped.joined(separator: sep)
    }

    private func toSlug(_ s: String, locale: Locale) -> String {
        let lowered = s.lowercased(with: locale)
        let noDiacritics = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
        let replaced = noDiacritics.replacingOccurrences(of: "[\\s_–—]+", with: "-", options: .regularExpression)
        let filtered = replaced.replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        let collapsed = filtered.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    struct Token { enum Kind { case word, sep }; var text: String; var kind: Kind }
    private func splitByWordBoundaries(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var isWord = false
        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(Token(text: current, kind: isWord ? .word : .sep))
            current = ""
        }
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "'" {
                if !isWord { flush(); isWord = true }
                current.append(ch)
            } else {
                if isWord { flush(); isWord = false }
                current.append(ch)
            }
        }
        flush()
        return tokens
    }
    
    private func extractWords(_ s: String, locale: Locale) -> [String] {
        let raw = s.unicodeScalars.map { Character($0) }
        var buf = ""
        var words: [String] = []
        func push() { if !buf.isEmpty { words.append(buf); buf = "" } }
        for ch in raw {
            if ch.isLetter || ch.isNumber { buf.append(ch) }
            else if ch == "'" && !buf.isEmpty { buf.append(ch) }
            else { push() }
        }
        push()
        return words
    }
    
    private func capitalizeFirst(_ w: String, locale: Locale) -> String {
        guard let first = w.first else { return w }
        return String(first).uppercased(with: locale) + String(w.dropFirst())
    }
}
