import Foundation
import AppKit

@Observable
class RegexViewModel {
    var pattern: String = "" { didSet { runAllIfNeeded() } }
    var replacement: String = "" { didSet { if autoUpdate { runReplace() } } }
    var testString: String = "" { didSet { runAllIfNeeded() } }
    
    // Options
    var optCaseInsensitive: Bool { didSet { save("regex.caseInsensitive", optCaseInsensitive) } }
    var optAnchorsMatchLines: Bool { didSet { save("regex.anchorsMatchLines", optAnchorsMatchLines) } }
    var optDotMatchesNewlines: Bool { didSet { save("regex.dotMatchesNewlines", optDotMatchesNewlines) } }
    var optAllowCommentsWhitespace: Bool { didSet { save("regex.allowCommentsWhitespace", optAllowCommentsWhitespace) } }
    var optUnicodeWordBoundaries: Bool { didSet { save("regex.unicodeWordBoundaries", optUnicodeWordBoundaries) } }
    var optUnixLineSeparators: Bool { didSet { save("regex.unixLineSeparators", optUnixLineSeparators) } }
    
    var autoUpdate: Bool { didSet { save("regex.auto", autoUpdate) } }
    var liveHighlight: Bool { didSet { save("regex.liveHighlight", liveHighlight) } }
    
    // Results
    var matches: [RegexMatchInfo] = []
    var highlightedNS = NSAttributedString(string: "")
    var replacedOutput: String = ""
    var errorMessage: String?
    
    private let groupPalette: [NSColor] = [
        .systemBlue, .systemGreen, .systemPink, .systemOrange,
        .systemPurple, .systemTeal, .systemIndigo, .systemMint,
        .systemBrown, .systemRed
    ]
    
    init() {
        self.optCaseInsensitive = Self.loadBool("regex.caseInsensitive")
        self.optAnchorsMatchLines = Self.loadBool("regex.anchorsMatchLines")
        self.optDotMatchesNewlines = Self.loadBool("regex.dotMatchesNewlines")
        self.optAllowCommentsWhitespace = Self.loadBool("regex.allowCommentsWhitespace")
        self.optUnicodeWordBoundaries = Self.loadBool("regex.unicodeWordBoundaries")
        self.optUnixLineSeparators = Self.loadBool("regex.unixLineSeparators")
        
        self.autoUpdate = Self.loadBoolDefaultTrue("regex.auto")
        self.liveHighlight = Self.loadBoolDefaultTrue("regex.liveHighlight")
    }
    
    private func save(_ key: String, _ value: Bool) { UserDefaults.standard.set(value, forKey: key); runAllIfNeeded() }
    private static func loadBool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    private static func loadBoolDefaultTrue(_ key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func runAllIfNeeded() {
        guard autoUpdate else { return }
        runRegex()
        runReplace()
    }
    
    func runRegex() {
        errorMessage = nil
        matches.removeAll()

        let options = buildOptions()
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            self.errorMessage = error.localizedDescription
            self.highlightedNS = NSAttributedString(string: testString, attributes: baseTextAttrs())
            return
        }

        let fullRange = NSRange(testString.startIndex..<testString.endIndex, in: testString)
        let results = regex.matches(in: testString, options: [], range: fullRange)
        let names = extractNamedGroupNames(from: pattern)
        let groupCount = regex.numberOfCaptureGroups

        let res: [RegexMatchInfo] = results.map { r in
            let sub = substring(testString, nsRange: r.range) ?? ""
            var groups: [RegexGroupInfo] = []
            for idx in 0...groupCount {
                let gr = r.range(at: idx)
                if gr.location != NSNotFound {
                    let val = substring(testString, nsRange: gr)
                    let name = nameForGroup(range: gr, names: names, result: r)
                    groups.append(RegexGroupInfo(index: idx, name: name, range: gr, value: val))
                }
            }
            return RegexMatchInfo(range: r.range, substring: sub, groups: groups)
        }
        self.matches = res

        if liveHighlight {
            self.highlightedNS = makeHighlighted(testString: testString, matches: res, groupCount: groupCount)
        } else {
            self.highlightedNS = NSAttributedString(string: testString, attributes: baseTextAttrs())
        }
    }
    
    func runReplace() {
        errorMessage = nil
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: buildOptions())
            let range = NSRange(testString.startIndex..<testString.endIndex, in: testString)
            let replaced = regex.stringByReplacingMatches(in: testString, options: [], range: range, withTemplate: replacement)
            self.replacedOutput = replaced
        } catch {
            self.errorMessage = error.localizedDescription
            self.replacedOutput = ""
        }
    }
    
    func clearAll() {
        pattern = ""
        replacement = ""
        testString = ""
        matches.removeAll()
        highlightedNS = NSAttributedString(string: "")
        replacedOutput = ""
        errorMessage = nil
    }
    
    private func buildOptions() -> NSRegularExpression.Options {
        var opts: NSRegularExpression.Options = []
        if optCaseInsensitive { opts.insert(.caseInsensitive) }
        if optAnchorsMatchLines { opts.insert(.anchorsMatchLines) }
        if optDotMatchesNewlines { opts.insert(.dotMatchesLineSeparators) }
        if optAllowCommentsWhitespace { opts.insert(.allowCommentsAndWhitespace) }
        if optUnicodeWordBoundaries { opts.insert(.useUnicodeWordBoundaries) }
        if optUnixLineSeparators { opts.insert(.useUnixLineSeparators) }
        return opts
    }
    
    var flagsString: String {
        var f = ""
        if optCaseInsensitive { f += "i" }
        if optAnchorsMatchLines { f += "m" }
        if optDotMatchesNewlines { f += "s" }
        if optAllowCommentsWhitespace { f += "x" }
        if optUnicodeWordBoundaries { f += "u" }
        if optUnixLineSeparators { f += "U" }
        return f.isEmpty ? "∅" : f
    }
    
    private func substring(_ s: String, nsRange: NSRange) -> String? {
        guard let r = Range(nsRange, in: s) else { return nil }
        return String(s[r])
    }
    
    private func extractNamedGroupNames(from pattern: String) -> [String] {
        let pat = #"\(\?\<([A-Za-z_][A-Za-z0-9_]*)\>"#
        guard let reg = try? NSRegularExpression(pattern: pat) else { return [] }
        let ns = pattern as NSString
        let ms = reg.matches(in: pattern, range: NSRange(location: 0, length: ns.length))
        var names: [String] = []
        for m in ms {
            let name = ns.substring(with: m.range(at: 1))
            names.append(name)
        }
        return names
    }

    private func nameForGroup(range: NSRange, names: [String], result: NSTextCheckingResult) -> String? {
        for n in names {
            let rn = result.range(withName: n)
            if rn.location != NSNotFound && NSEqualRanges(rn, range) { return n }
        }
        return nil
    }

    private func baseTextAttrs() -> [NSAttributedString.Key: Any] {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return [.font: font, .foregroundColor: NSColor.labelColor]
    }

    private func makeHighlighted(testString: String, matches: [RegexMatchInfo], groupCount: Int) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: testString, attributes: baseTextAttrs())
        let matchBg = NSColor.systemYellow.withAlphaComponent(0.24)
        for m in matches {
            attr.addAttribute(.backgroundColor, value: matchBg, range: m.range)
        }
        if groupCount > 0 {
            for m in matches {
                for g in m.groups {
                    let color = groupColor(for: g.index).withAlphaComponent(0.25)
                    attr.addAttribute(.backgroundColor, value: color, range: g.range)
                }
            }
        }
        return attr
    }

    private func groupColor(for index: Int) -> NSColor {
        let i = max(0, index - 1)
        return groupPalette[i % groupPalette.count]
    }
}
