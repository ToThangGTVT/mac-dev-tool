import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct RegexTesterToolView: View {
    @State private var vm = RegexViewModel()
    @State private var selectedTab: Int = 0
    @State private var isTargeted: Bool = false
    @State private var showOptionsGuide: Bool = false
    
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
                Button { vm.runAllIfNeeded() } label: { Label("Run Regex", systemImage: "play.fill") }
                
                Button { copyOutput() } label: { Label("Copy", systemImage: "doc.on.doc") }
                
                Button {
                    if let text = PasteboardHelper.paste() { vm.testString = text }
                } label: { Label("Paste Test String", systemImage: "doc.on.clipboard") }
                
                Button(role: .destructive) { vm.clearAll() } label: { Label("Clear", systemImage: "trash") }
                .keyboardShortcut("k", modifiers: [.command])
                
                Spacer()
                
                Button { showOptionsGuide.toggle() } label: { Label("Regex Help", systemImage: "questionmark.circle") }
                .popover(isPresented: $showOptionsGuide) { optionsGuideView }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("/")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("pattern (VD: ^[a-z]+$)", text: $vm.pattern)
                    .font(.system(.title3, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                Text("/")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text(vm.flagsString)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.blue)
                    .frame(minWidth: 40, alignment: .leading)
            }
            
            HStack {
                Toggle("i", isOn: $vm.optCaseInsensitive).help("Case Insensitive")
                Toggle("m", isOn: $vm.optAnchorsMatchLines).help("Anchors Match Lines (^ $)")
                Toggle("s", isOn: $vm.optDotMatchesNewlines).help("Dot Matches Newlines")
                Toggle("x", isOn: $vm.optAllowCommentsWhitespace).help("Allow Comments & Whitespace")
                Toggle("u", isOn: $vm.optUnicodeWordBoundaries).help("Unicode Word Boundaries")
                Toggle("U", isOn: $vm.optUnixLineSeparators).help("Unix Line Separators")
                Spacer()
                Toggle("Auto-Update", isOn: $vm.autoUpdate)
                Toggle("Live Highlight", isOn: $vm.liveHighlight)
            }
            .toggleStyle(.button)
            .controlSize(.small)
        }.padding(12)
    }

    private var editors: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Test String").font(.headline)
                    Spacer()
                    Button { vm.testString = "" } label: { Image(systemName: "xmark.circle").foregroundColor(.secondary) }.buttonStyle(.borderless)
                }
                MacEditor(text: $vm.testString)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { p in DropHandler.handleTextDrop(providers: p) { vm.testString = $0; vm.runAllIfNeeded() } }
                
                HStack {
                    Text("Replacement").font(.headline)
                    TextField("$1-$2", text: $vm.replacement).textFieldStyle(.roundedBorder)
                    Button("Replace") { vm.runReplace() }.buttonStyle(.borderedProminent)
                }.padding(.top, 4)
            }.padding(12).frame(minWidth: 350)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("List Matches").tag(0)
                    Text("Highlighted").tag(1)
                    Text("Replaced").tag(2)
                }.pickerStyle(.segmented).padding([.horizontal, .top], 12).padding(.bottom, 8)
                
                ZStack {
                    if selectedTab == 0 { RegexMatchesListView(matches: vm.matches) }
                    else if selectedTab == 1 { RegexHighlightedView(highlightedNS: vm.highlightedNS) }
                    else { RegexReplacedView(replacedOutput: vm.replacedOutput) }
                }
            }.frame(minWidth: 400)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
            } else {
                Text("Matches: \(vm.matches.count)").foregroundColor(.secondary)
            }
            Spacer()
        }.padding(8)
    }

    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch selectedTab {
        case 0:
            var s = "Matches: \(vm.matches.count)\n"
            for (i, m) in vm.matches.enumerated() {
                s += "Match #\(i+1) [\(m.range.location)..<\(m.range.location + m.range.length))]: \(m.substring)\n"
                if !m.groups.isEmpty {
                    for g in m.groups {
                        s += "  \(g.name ?? "#\(g.index)") [\(g.range.location)..<\(g.range.location + g.range.length))]: \(g.value ?? "nil")\n"
                    }
                }
            }
            pb.setString(s, forType: .string)
        case 1:
            pb.setString(vm.highlightedNS.string, forType: .string)
        default:
            pb.setString(vm.replacedOutput, forType: .string)
        }
    }

    private var optionsGuideView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Các Cờ Mặc Định (NSRegularExpression)").font(.headline)
            Group {
                Text("**i (Case Insensitive)**: Không phân biệt hoa thường.")
                Text("**m (Anchors Match Lines)**: ^ và $ khớp với đầu/cuối của từng dòng (thay vì toàn bộ chuỗi).")
                Text("**s (Dot Matches Newlines)**: Dấu . bao gồm cả ký tự xuống dòng.")
                Text("**x (Allow Comments And Whitespace)**: Bỏ qua khoảng trắng không escape và comment #.")
                Text("**u (Use Unicode Word Boundaries)**: Biên từ \\b nhận diện theo chuẩn Unicode thay vì chỉ ASCII.")
                Text("**U (Use Unix Line Separators)**: Chỉ coi \\n là dấu xuống dòng.")
            }.font(.subheadline)
            Text("Cú pháp Group: (?<name>...) hoặc $1, $2 trong replace.").font(.caption).padding(.top, 4).foregroundColor(.secondary)
        }.padding().frame(width: 400)
    }
}
