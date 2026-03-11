//
//  RegexTesterToolView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct RegexTesterToolView: View {
    // MARK: - Options
    @AppStorage("regex.pattern") private var pattern: String = #"(\w+)"#
    @AppStorage("regex.replacement") private var replacement: String = #"$0"# // dùng trong Replace
    @AppStorage("regex.caseInsensitive") private var optCaseInsensitive: Bool = false  // i
    @AppStorage("regex.anchorsMatchLines") private var optAnchorsMatchLines: Bool = true // m
    @AppStorage("regex.dotMatchesNewlines") private var optDotMatchesNewlines: Bool = false // s
    @AppStorage("regex.allowCommentsWhitespace") private var optAllowCommentsWhitespace: Bool = false // x
    @AppStorage("regex.useUnicodeWordBoundaries") private var optUnicodeWordBoundaries: Bool = true // u
    @AppStorage("regex.useUnixLineSeparators") private var optUnixLineSeparators: Bool = false
    @AppStorage("regex.autoUpdate") private var autoUpdate: Bool = true
    @AppStorage("regex.liveHighlight") private var liveHighlight: Bool = true
    @State private var showInspector: Bool = true

    @State private var testString: String = """
    Hello regex 101!
    Email: test@example.com
    Line-2: foo bar baz
    """
    @State private var errorMessage: String?
    @State private var matches: [MatchInfo] = []
    @State private var replacedOutput: String = ""
    @State private var highlightedNS: NSAttributedString = NSAttributedString(string: "")

    @State private var isTargetedDrop: Bool = false
    @State private var selectedTab: Int = 0 // 0 Matches, 1 Highlight, 2 Replace

    // Colors for groups
    private let groupPalette: [NSColor] = [
        .systemPink, .systemTeal, .systemOrange, .systemGreen,
        .systemPurple, .systemRed, .systemBlue, .systemBrown
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            editors
            Divider()
            footer
        }
        .navigationTitle("Regex Tester")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    runRegex()
                } label: {
                    Label("Test", systemImage: "magnifyingglass")
                }
                .keyboardShortcut(.return)

                Button {
                    runReplace()
                    selectedTab = 2
                } label: {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help(selectedTab == 2 ? "Copy Replaced Output" : "Copy Matches/Highlight text")
                
                Button(role: .destructive) {
                    clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])

                Spacer()

                Button { withAnimation { showInspector.toggle() } } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.trailing")
                }
                .help("Toggle Results Sidebar")
            }
        }
        .inspector(isPresented: $showInspector) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
        }
        .onAppear {
            runAllIfNeeded()
        }
        .onChange(of: pattern) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: testString) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optCaseInsensitive) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optAnchorsMatchLines) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optDotMatchesNewlines) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optAllowCommentsWhitespace) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optUnicodeWordBoundaries) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: optUnixLineSeparators) { oldValue, newValue in runAllIfNeeded() }
        .onChange(of: replacement) { oldValue, newValue in if autoUpdate { runReplace() } }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Pattern")
                    .font(.headline)
                TextField(#"/pattern/flags"#, text: $pattern, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .help("Sử dụng cú pháp NSRegularExpression/ICU. Có thể dùng named groups: (?<name>...)")
            }
            flagsView
            HStack(spacing: 12) {
                Toggle("Auto update", isOn: $autoUpdate)
                Toggle("Live highlight", isOn: $liveHighlight)
                Spacer()

                // Quick info: /.../flags
                Text(verbatim: "Flags: \(flagsString())")
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
        }
        .padding(12)
    }

    private var flagsView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
            Group {
                Toggle("i", isOn: $optCaseInsensitive)
                    .help("Case-insensitive")
                Toggle("m", isOn: $optAnchorsMatchLines)
                    .help("^ và $ match theo từng dòng")
                Toggle("s", isOn: $optDotMatchesNewlines)
                    .help("Dấu chấm . match cả newline")
                Toggle("x", isOn: $optAllowCommentsWhitespace)
                    .help("Bỏ qua khoảng trắng & cho phép comment trong pattern")
                Toggle("u", isOn: $optUnicodeWordBoundaries)
                    .help("Sử dụng biên từ Unicode")
                Toggle("Unix ␤", isOn: $optUnixLineSeparators)
                    .help("Dùng Unix line separators")
            }
            .toggleStyle(.switch)
            .fixedSize() // Giúp toggle không bị ép dẹt
        }
    }
    
    // MARK: - Editors
    private var editors: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test String").font(.headline)
                Spacer()
                Button {
                    testString = ""
                } label: {
                    Image(systemName: "xmark.circle").foregroundColor(.secondary)
                }.buttonStyle(.borderless)
            }

            MacEditor(text: $testString)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargetedDrop ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargetedDrop) { providers in
                    handleDrop(providers: providers)
                }

            GroupBox("Replacement") {
                HStack(spacing: 10) {
                    TextField("Replacement (ví dụ: $0, $1, $2, hoặc ${name})", text: $replacement)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Run Replace") {
                        runReplace()
                        selectedTab = 2
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 8) {
                Button("Test", action: runRegex)
                    .buttonStyle(.borderedProminent)
                Button("Replace", action: {
                    runReplace()
                    selectedTab = 2
                })
                Button("Paste", action: pasteToTestString)
                Spacer()
                Button("Clear", role: .destructive, action: clearAll)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $selectedTab) {
                Text("Matches").tag(0)
                Text("Highlight").tag(1)
                Text("Replaced").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            if selectedTab == 0 {
                matchesListView
            } else if selectedTab == 1 {
                highlightedView
            } else {
                replacedView
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Matches view
    private var matchesListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kết quả")
                    .font(.headline)
                Spacer()
                Text("Matches: \(matches.count)")
                    .foregroundColor(.secondary)
            }

            if let e = errorMessage, !e.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(e).foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { (idx, m) in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Match #\(idx + 1)  [\(formatNSRange(m.range))]")
                                    .font(.headline)
                                Spacer()
                            }
                            Text(verbatim: m.substring)
                                .font(.system(.body, design: .monospaced))
                                .padding(6)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))

                            if !m.groups.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Groups").font(.subheadline).bold()
                                    ForEach(m.groups, id: \.index) { g in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(Color(groupColor(for: g.index)))
                                                .frame(width: 8, height: 8)
                                                .padding(.top, 5)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(g.name ?? "#\(g.index)")  [\(formatNSRange(g.range))]")
                                                    .font(.caption).bold()
                                                Text(verbatim: g.value ?? "nil")
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.7))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Highlighted view
    private var highlightedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlighted").font(.headline)
            
            ScrollView {
                Text(AttributedString(highlightedNS))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 240)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            
            if let e = errorMessage, !e.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(e).foregroundColor(.secondary)
                }
            } else {
                Text(" ")
                    .hidden()
            }
        }
    }

    // MARK: - Replaced view
    private var replacedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Replaced Output").font(.headline)
                Spacer()
                Text("Dùng replacement: \(replacement)")
                    .foregroundColor(.secondary)
            }
            ScrollView {
                Text(replacedOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 240)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            if let e = errorMessage, !e.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(e).foregroundColor(.secondary)
                }
            } else {
                Text(" ").hidden()
            }
        }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Text("Matches: \(matches.count)")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(8)
    }

    // MARK: - Actions
    private func runAllIfNeeded() {
        guard autoUpdate else { return }
        runRegex()
        runReplace()
    }

    private func runRegex() {
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

        let res: [MatchInfo] = results.map { r in
            let sub = substring(testString, nsRange: r.range) ?? ""
            var groups: [GroupInfo] = []
            for idx in 1...max(groupCount, 0) {
                let gr = r.range(at: idx)
                if gr.location != NSNotFound {
                    let val = substring(testString, nsRange: gr)
                    let name = nameForGroup(range: gr, names: names, result: r)
                    groups.append(GroupInfo(index: idx, name: name, range: gr, value: val))
                }
            }
            return MatchInfo(range: r.range, substring: sub, groups: groups)
        }
        self.matches = res

        if liveHighlight {
            self.highlightedNS = makeHighlighted(testString: testString, matches: res, groupCount: groupCount)
        } else {
            self.highlightedNS = NSAttributedString(string: testString, attributes: baseTextAttrs())
        }
    }

    private func runReplace() {
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

    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch selectedTab {
        case 0:
            // Copy matches as plain text summary
            var s = "Matches: \(matches.count)\n"
            for (i, m) in matches.enumerated() {
                s += "Match #\(i+1) [\(formatNSRange(m.range))]: \(m.substring)\n"
                if !m.groups.isEmpty {
                    for g in m.groups {
                        s += "  \(g.name ?? "#\(g.index)") [\(formatNSRange(g.range))]: \(g.value ?? "nil")\n"
                    }
                }
            }
            pb.setString(s, forType: .string)
        case 1:
            pb.setString(highlightedNS.string, forType: .string)
        default:
            pb.setString(replacedOutput, forType: .string)
        }
    }

    private func clearAll() {
        pattern = ""
        replacement = ""
        testString = ""
        matches.removeAll()
        highlightedNS = NSAttributedString(string: "")
        replacedOutput = ""
        errorMessage = nil
    }

    private func pasteToTestString() {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) {
            testString = str
        }
    }

    // MARK: - Options & helpers
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

    private func flagsString() -> String {
        var f = ""
        if optCaseInsensitive { f += "i" }
        if optAnchorsMatchLines { f += "m" }
        if optDotMatchesNewlines { f += "s" }
        if optAllowCommentsWhitespace { f += "x" }
        if optUnicodeWordBoundaries { f += "u" }
        if optUnixLineSeparators { f += "U" } // custom hiển thị cho tiện phân biệt
        return f.isEmpty ? "∅" : f
    }

    private func substring(_ s: String, nsRange: NSRange) -> String? {
        guard let r = Range(nsRange, in: s) else { return nil }
        return String(s[r])
    }

    private func formatNSRange(_ r: NSRange) -> String {
        "[\(r.location)..<\(r.location + r.length))"
    }

    // MARK: - Named groups
    private func extractNamedGroupNames(from pattern: String) -> [String] {
        // Tìm (?<name> ... )
        // Lưu ý: heuristic — đủ tốt cho đa số pattern thực tế
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
        // So khớp name bằng cách so sánh range(withName:) với range(at:)
        for n in names {
            let rn = result.range(withName: n)
            if rn.location != NSNotFound && NSEqualRanges(rn, range) {
                return n
            }
        }
        return nil
    }

    // MARK: - Highlight
    private func baseTextAttrs() -> [NSAttributedString.Key: Any] {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return [.font: font, .foregroundColor: NSColor.labelColor]
    }

    private func makeHighlighted(testString: String, matches: [MatchInfo], groupCount: Int) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: testString, attributes: baseTextAttrs())

        // Full match layer
        let matchBg = NSColor.systemYellow.withAlphaComponent(0.24)
        for m in matches {
            attr.addAttribute(.backgroundColor, value: matchBg, range: m.range)
        }

        // Groups layer
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

    // MARK: - Drag & Drop
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for p in providers {
            if p.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = p.loadObject(ofClass: NSString.self) { item, _ in
                    if let text = item as? NSString {
                        DispatchQueue.main.async {
                            self.testString = text as String
                            self.runAllIfNeeded()
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
                            self.testString = content
                            self.runAllIfNeeded()
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    // MARK: - Models
    private struct MatchInfo {
        let range: NSRange
        let substring: String
        let groups: [GroupInfo]
    }
    private struct GroupInfo {
        let index: Int
        let name: String?
        let range: NSRange
        let value: String?
    }
}

struct MacEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        let textView = scrollView.documentView as! NSTextView
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        
        // Cực kì quan trọng để chống crash AppKit:
        // Yêu cầu NSTextView không tự bành trướng width theo nội dung mà bám sát scroll view
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        
        // ScrollView bám sát vào Container ngoài của SwiftUI
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let tv = nsView.documentView as? NSTextView {
            if tv.string != text {
                let currentSelectedRange = tv.selectedRange()
                tv.string = text
                if currentSelectedRange.location <= text.count {
                    tv.setSelectedRange(currentSelectedRange)
                }
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditor
        
        init(_ parent: MacEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

