//
//  TextCaseToolView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct TextCaseToolView: View {
    // MARK: - Chế độ chuyển đổi
    enum Mode: String, CaseIterable, Identifiable {
        case lower = "lowercase"
        case upper = "UPPERCASE"
        case sentence = "Sentence case"
        case title = "Title Case"
        case capitalize = "Capitalize Words"
        case inverse = "Inverse Case"
        case alternating = "aLtErNaTiNg cAsE"
        case camel = "camelCase"
        case pascal = "PascalCase"
        case snake = "snake_case"
        case kebab = "kebab-case"
        case constant = "CONSTANT_CASE"
        case slug = "slugify"
        
        var id: String { rawValue }
    }
    
    // MARK: - Tùy chọn & trạng thái
    @AppStorage("textcase.mode") private var mode: Mode = .title
    @AppStorage("textcase.autoUpdate") private var autoUpdate: Bool = true
    @AppStorage("textcase.localeID") private var localeID: String = Locale.current.identifier
    @AppStorage("textcase.keepAcronymsUpper") private var keepAcronymsUpper: Bool = true
    @AppStorage("textcase.collapseSpaces") private var collapseSpaces: Bool = true
    @AppStorage("textcase.altStartLower") private var altStartLower: Bool = true
    @AppStorage("textcase.smallWords") private var smallWordsRaw: String =
        "a, an, the, and, but, or, nor, as, at, by, for, in, of, on, per, to, vs, via"
    
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            editors
            Divider()
            footer
        }
        .navigationTitle("Text Case (convertcase)")
        .toolbar {
            ToolbarItemGroup {
                Button { transformNow() } label: {
                    Label("Transform", systemImage: "textformat")
                }
                .keyboardShortcut(.return)
                
                Button { copyOutput() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(output.isEmpty)
                
                Button { pasteToInput() } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                
                Button(role: .destructive) { clearAll() } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .padding(.bottom, 4)
        .onChange(of: input) { _ in if autoUpdate { transformNow() } }
        .onChange(of: mode) { _ in if autoUpdate { transformNow() } }
        .onChange(of: localeID) { _ in if autoUpdate { transformNow() } }
        .onChange(of: keepAcronymsUpper) { _ in if autoUpdate { transformNow() } }
        .onChange(of: collapseSpaces) { _ in if autoUpdate { transformNow() } }
        .onChange(of: altStartLower) { _ in if autoUpdate { transformNow() } }
        .onChange(of: smallWordsRaw) { _ in if autoUpdate { transformNow() } }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Picker("Chế độ", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .frame(width: 240)
            
            TextField("Locale (ví dụ: en_US, vi_VN)", text: $localeID)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .help("Ảnh hưởng chữ hoa/thường theo ngôn ngữ (đặc biệt tiếng Thổ Nhĩ Kỳ, v.v.)")
            
            Toggle("Auto update", isOn: $autoUpdate)
            
            Divider().frame(height: 22)
            
            if mode == .title {
                TextField("Small words (phẩy ngăn):", text: $smallWordsRaw)
                    .textFieldStyle(.roundedBorder)
                    .help("Những từ nhỏ sẽ để thường trừ khi đứng đầu/cuối tiêu đề")
                Toggle("Giữ ACRONYMS", isOn: $keepAcronymsUpper)
            } else if mode == .alternating {
                Toggle("Bắt đầu bằng chữ thường", isOn: $altStartLower)
            } else {
                Toggle("Gộp khoảng trắng", isOn: $collapseSpaces)
                Toggle("Giữ ACRONYMS", isOn: $keepAcronymsUpper)
            }
            
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Editors
    private var editors: some View {
        HStack(spacing: 0) {
            // Input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input").font(.headline)
                    Spacer()
                    Button {
                        input = ""
                    } label: {
                        Image(systemName: "xmark.circle").foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                
                TextEditor(text: $input)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                        handleDrop(providers: providers)
                    }
                
                HStack(spacing: 8) {
                    Button("Transform", action: transformNow)
                        .buttonStyle(.borderedProminent)
                    Button("Paste", action: pasteToInput)
                    Spacer()
                    Button("Clear", role: .destructive, action: clearAll)
                }
            }
            .padding(12)
            .frame(minWidth: 420)
            
            Divider()
            
            // Output
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output").font(.headline)
                    Spacer()
                    Button { copyOutput() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(output.isEmpty)
                }
                
                TextEditor(text: .constant(output))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(true)
                
                if let e = errorMessage, !e.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                        Text(e).foregroundColor(.secondary)
                    }
                } else {
                    Text(" ").hidden()
                }
                
                HStack {
                    let stats = outputStats(output)
                    Text("Ký tự: \(stats.characters) • Từ: \(stats.words) • Dòng: \(stats.lines)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(12)
            .frame(minWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Text(footerHelp)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(8)
    }
    
    private var footerHelp: String {
        switch mode {
        case .lower: return "Chuyển tất cả thành chữ thường theo locale."
        case .upper: return "Chuyển tất cả thành CHỮ HOA theo locale."
        case .sentence: return "Viết hoa chữ đầu mỗi câu. Các chữ còn lại thường."
        case .title: return "Title Case: Viết hoa chữ cái đầu mỗi từ trừ small words (trừ khi đầu/cuối)."
        case .capitalize: return "Viết hoa chữ cái đầu mỗi từ, không áp dụng quy tắc small words."
        case .inverse: return "Đảo hoa/thường từng ký tự."
        case .alternating: return "Xen kẽ hoa-thường. Chỉ đếm trên ký tự chữ."
        case .camel: return "camelCase: viết thường từ đầu, các từ sau viết Hoa chữ đầu, bỏ dấu/cách."
        case .pascal: return "PascalCase: viết Hoa chữ đầu mỗi từ, bỏ dấu/cách."
        case .snake: return "snake_case: chữ thường, ngăn bằng dấu gạch dưới."
        case .kebab: return "kebab-case: chữ thường, ngăn bằng dấu gạch nối."
        case .constant: return "CONSTANT_CASE: CHỮ HOA, ngăn bằng dấu gạch dưới."
        case .slug: return "slugify: chữ thường, bỏ dấu, chỉ chữ-số, nối bằng dấu gạch nối."
        }
    }
    
    // MARK: - Actions
    private func transformNow() {
        errorMessage = nil
        let loc = Locale(identifier: localeID)
        var text = input
        
        if collapseSpaces {
            // Chuẩn hoá khoảng trắng: trim + đổi nhiều spaces/newlines thành 1 space (trừ giữ newline để đếm dòng)
            text = normalizeSpaces(text)
        }
        
        switch mode {
        case .lower:
            output = text.lowercased(with: loc)
        case .upper:
            output = text.uppercased(with: loc)
        case .sentence:
            output = toSentenceCase(text, locale: loc)
        case .title:
            output = toTitleCase(text, locale: loc,
                                 smallWords: parseSmallWords(smallWordsRaw),
                                 keepAcronyms: keepAcronymsUpper)
        case .capitalize:
            output = capitalizeWords(text, locale: loc, keepAcronyms: keepAcronymsUpper)
        case .inverse:
            output = inverseCase(text)
        case .alternating:
            output = alternatingCase(text, startLower: altStartLower)
        case .camel:
            output = toCamelCase(text, locale: loc, keepAcronyms: keepAcronymsUpper)
        case .pascal:
            output = toPascalCase(text, locale: loc, keepAcronyms: keepAcronymsUpper)
        case .snake:
            output = toSeparatedCase(text, sep: "_", upper: false, locale: loc)
        case .kebab:
            output = toSeparatedCase(text, sep: "-", upper: false, locale: loc)
        case .constant:
            output = toSeparatedCase(text, sep: "_", upper: true, locale: loc)
        case .slug:
            output = toSlug(text, locale: loc)
        }
    }
    
    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
    }
    private func pasteToInput() {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) {
            input = str
        }
    }
    private func clearAll() {
        input = ""
        output = ""
        errorMessage = nil
    }
    
    // MARK: - Drop handling
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for p in providers {
            if p.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = p.loadObject(ofClass: NSString.self) { item, _ in
                    if let nsstr = item as? NSString {
                        let text = nsstr as String
                        DispatchQueue.main.async {
                            self.input = text
                            if self.autoUpdate { self.transformNow() }
                        }
                    }
                }
                return true
            } else if p.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
                    guard
                        let urlData,
                        let url = URL(dataRepresentation: urlData as! Data, relativeTo: nil)
                    else { return }
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.input = content
                            if self.autoUpdate { self.transformNow() }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    // MARK: - Stats
    private func outputStats(_ s: String) -> (characters: Int, words: Int, lines: Int) {
        let chars = s.count
        let words = s.split { !$0.isLetter && !$0.isNumber }.count
        let lines = s.split(whereSeparator: \.isNewline).count
        return (chars, words, max(lines, s.isEmpty ? 0 : 1))
    }
    
    // MARK: - Helpers (normalize, small words, tokens)
    private func normalizeSpaces(_ s: String) -> String {
        // Giữ newline để phân dòng, nhưng collapse nhiều khoảng trắng liên tiếp trong 1 dòng.
        let lines = s.components(separatedBy: .newlines)
        let collapsed = lines.map { line in
            let parts = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            return parts.joined(separator: " ")
        }
        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseSmallWords(_ raw: String) -> Set<String> {
        let arr = raw
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Set(arr)
    }
    
    private func tokenizeWords(_ s: String) -> [String] {
        // Cắt theo biên từ cơ bản: ký tự không phải chữ/số coi như phân tách
        let comps = s.split { !( $0.isLetter || $0.isNumber ) }
        return comps.map(String.init)
    }
    
    private func isAcronym(_ w: String) -> Bool {
        guard w.count >= 2 else { return false }
        // "JSON", "API", "HTML5" → coi là acronym nếu >= 2 ký tự và đa số là chữ in hoa
        let letters = w.filter { $0.isLetter }
        guard letters.count >= 2 else { return false }
        let upperCount = letters.filter { $0.isUppercase }.count
        return upperCount >= max(2, letters.count - 1)
    }
    
    // MARK: - Transformations
    private func toSentenceCase(_ s: String, locale: Locale) -> String {
        // Heuristic: tách câu theo [.?!…] + xuống dòng. Lower tất cả rồi viết hoa chữ cái đầu câu.
        // Giữ nguyên ACRONYM nếu bật.
        let separators: CharacterSet = CharacterSet(charactersIn: ".!?…")
        var result = ""
        var startOfSentence = true
        
        for ch in s {
            if startOfSentence {
                if ch.isLetter {
                    let c = String(ch).uppercased(with: locale)
                    result.append(c)
                    startOfSentence = false
                } else {
                    result.append(ch)
                    if ch.isNewline { startOfSentence = true }
                    continue
                }
            } else {
                result.append(String(ch).lowercased(with: locale))
            }
            
            if let scalar = ch.unicodeScalars.first, separators.contains(scalar) {
                startOfSentence = true
            }
            if ch.isNewline {
                startOfSentence = true
            }
        }
        
        // Sửa lại các từ là acronym bị lower
        if keepAcronymsUpper {
            result = restoreAcronyms(from: s, into: result)
        }
        return result
    }
    
    private func restoreAcronyms(from original: String, into transformed: String) -> String {
        // Dựa trên token từ bản gốc: token nào là acronym → thay thế trong transformed bằng dạng upper
        // (cách đơn giản: duyệt từng token gốc, replace case-insensitive)
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
    
    private func toTitleCase(_ s: String, locale: Locale, smallWords: Set<String>, keepAcronyms: Bool) -> String {
        // Heuristic Title Case:
        // - Viết hoa chữ đầu mỗi từ
        // - small words để thường trừ khi ở đầu/cuối dòng/tiêu đề
        // - giữ nguyên acronym nếu bật
        // Xử lý theo từng dòng để không ảnh hưởng header nhiều dòng
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
            } else {
                out.append(ch)
            }
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
                if keepAcronyms, isAcronym(w) {
                    result += w.uppercased()
                } else {
                    result += capitalizeFirst(w.lowercased(with: locale), locale: locale)
                }
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
        // 1) hạ chữ, 2) bỏ dấu, 3) thay mọi khoảng trắng/underscore/hyphen liền kề bằng 1 '-', 4) lọc ký tự ngoài [a-z0-9-]
        let lowered = s.lowercased(with: locale)
        let noDiacritics = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
        // Thay khoảng trắng/underscore/–—… → '-'
        let replaced = noDiacritics.replacingOccurrences(of: "[\\s_–—]+", with: "-", options: .regularExpression)
        // Chỉ giữ a-z0-9- (ASCII); loại ký tự khác
        let filtered = replaced.replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        // Bỏ '-' đầu/cuối, gộp nhiều '-'
        let collapsed = filtered.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    // MARK: - Word boundaries
    private struct Token {
        enum Kind { case word, sep }
        var text: String
        var kind: Kind
    }
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
        // Lấy chuỗi chữ/số (coi ' và . trong số là phần của token nếu cần)
        let raw = s.unicodeScalars.map { Character($0) }
        var buf = ""
        var words: [String] = []
        func push() {
            if !buf.isEmpty {
                words.append(buf)
                buf = ""
            }
        }
        for ch in raw {
            if ch.isLetter || ch.isNumber {
                buf.append(ch)
            } else if ch == "'" && !buf.isEmpty {
                // keep apostrophes inside words (e.g., don't -> don't)
                buf.append(ch)
            } else {
                push()
            }
        }
        push()
        return words
    }
    
    private func capitalizeFirst(_ w: String, locale: Locale) -> String {
        guard let first = w.first else { return w }
        let head = String(first).uppercased(with: locale)
        let tail = String(w.dropFirst())
        return head + tail
    }
}
