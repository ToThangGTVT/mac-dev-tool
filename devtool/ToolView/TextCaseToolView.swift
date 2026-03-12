import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct TextCaseToolView: View {
    @State private var vm = TextCaseViewModel()
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            editors
            Divider()
            footer
        }
        .navigationTitle("Text Case Converter")
        .toolbar {
            ToolbarItemGroup {
                Button { vm.transformNow() } label: { Label("Transform", systemImage: "arrow.triangle.2.circlepath") }
                
                Button { PasteboardHelper.copy(vm.output) } label: { Label("Copy Output", systemImage: "doc.on.doc") }.disabled(vm.output.isEmpty)
                
                Button { if let text = PasteboardHelper.paste() { vm.input = text } } label: { Label("Paste Input", systemImage: "doc.on.clipboard") }
                
                Button(role: .destructive) { vm.clearAll() } label: { Label("Clear", systemImage: "trash") }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 16) {
            Picker("Chế độ", selection: $vm.mode) {
                ForEach(TextCaseMode.allCases) { m in Text(m.rawValue).tag(m) }
            }.frame(width: 300)
            
            Toggle("Auto Update", isOn: $vm.autoUpdate)
            Toggle("Preserve Acronyms", isOn: $vm.preserveAcronyms)
                .help("Giữ nguyên các từ viết tắt (VD: JSON, API) khi chuyển sang Camel/Pascal/Title/Sentence case.")
            Spacer()
        }.padding(12)
    }

    private var editors: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input").font(.headline)
                    Spacer()
                    Button { vm.input = "" } label: { Image(systemName: "xmark.circle").foregroundColor(.secondary) }.buttonStyle(.borderless)
                }
                TextEditor(text: $vm.input)
                    .font(.system(.body, design: .monospaced))
                    .padding(8).background(Color(NSColor.textBackgroundColor)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                        DropHandler.handleTextDrop(providers: providers) { text in vm.input = text }
                    }
            }.padding(12).frame(minWidth: 420)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output").font(.headline)
                    Spacer()
                    Button { PasteboardHelper.copy(vm.output) } label: { Image(systemName: "doc.on.doc").foregroundColor(.secondary) }.buttonStyle(.borderless)
                }
                TextEditor(text: Binding(get: { vm.output }, set: { _ in }))
                    .font(.system(.body, design: .monospaced))
                    .padding(8).background(Color(NSColor.textBackgroundColor).opacity(0.5)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }.padding(12).frame(minWidth: 420)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
            } else {
                Text("\(vm.statsCharacters) chars, \(vm.statsWords) words, \(vm.statsLines) lines").foregroundColor(.secondary)
            }
            Spacer()
        }.padding(8)
    }
}
