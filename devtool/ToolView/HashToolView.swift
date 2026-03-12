import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct HashToolView: View {
    @State private var vm = HashViewModel()
    @State private var isTargeted: Bool = false
    @State private var showInspector: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            editors
            Divider()
            footer
        }
        .navigationTitle("Hash (MD5 / SHA‑1 / SHA‑256 / SHA‑384 / SHA‑512)")
        .toolbar {
            ToolbarItemGroup {
                Button { vm.computeHash() } label: { Label("Hash", systemImage: "shield.checkerboard") }
                .keyboardShortcut(.return)
                
                Button { PasteboardHelper.copy(vm.output) } label: { Label("Copy", systemImage: "doc.on.doc") }
                .disabled(vm.output.isEmpty)
                
                Button { if let text = PasteboardHelper.paste() { vm.input = text } } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                
                Button(role: .destructive) { vm.clearAll() } label: { Label("Clear", systemImage: "trash") }
                .keyboardShortcut("k", modifiers: [.command])

                Spacer()

                Button { withAnimation { showInspector.toggle() } } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.trailing")
                }.help("Toggle Results Sidebar")
            }
        }
        .padding(.bottom, 4)
        .inspector(isPresented: $showInspector) {
            inspectorContent.inspectorColumnWidth(min: 300, ideal: 400, max: 600)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Picker("Thuật toán", selection: $vm.algorithm) {
                ForEach(HashAlgorithm.allCases) { alg in Text(alg.rawValue).tag(alg) }
            }.frame(width: 200)
            
            Picker("Output", selection: $vm.outputFormat) {
                ForEach(HashOutputFormat.allCases) { fmt in Text(fmt.rawValue).tag(fmt) }
            }.frame(width: 200)
            
            Picker("Encoding", selection: $vm.stringEncoding) {
                ForEach(TextEncoding.allCases) { enc in Text(enc.rawValue).tag(enc) }
            }.frame(width: 140).disabled(vm.droppedFileURL != nil)
            
            Spacer()
        }.padding(12)
    }

    // MARK: - Editors
    private var editors: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input").font(.headline)
                    if let url = vm.droppedFileURL {
                        Spacer()
                        Label(url.lastPathComponent, systemImage: "doc").lineLimit(1).truncationMode(.middle)
                        Text("(\(vm.humanFileSize(bytes: vm.droppedFileSize)))").foregroundColor(.secondary)
                        Button { vm.removeDroppedFile() } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.borderless).help("Bỏ chọn file")
                    } else {
                        Spacer()
                        Button { vm.input = "" } label: { Image(systemName: "xmark.circle").foregroundColor(.secondary) }.buttonStyle(.borderless).help("Clear input")
                    }
                }
                
                TextEditor(text: Binding(get: { vm.input }, set: { if vm.droppedFileURL == nil { vm.input = $0 } }))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                    .disabled(vm.droppedFileURL != nil)
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                        vm.handleDrop(providers: providers)
                    }
                
                HStack(spacing: 8) {
                    Button("Hash", action: vm.computeHash).buttonStyle(.borderedProminent)
                    Button("Paste") { if let text = PasteboardHelper.paste() { vm.input = text } }.disabled(vm.droppedFileURL != nil)
                    Spacer()
                    Button("Clear", role: .destructive, action: vm.clearAll)
                }
            }
        }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output").font(.headline)
                Spacer()
                Button { PasteboardHelper.copy(vm.output) } label: { Image(systemName: "doc.on.doc").foregroundColor(.secondary) }.buttonStyle(.borderless).help("Copy output")
            }
            TextEditor(text: Binding(get: { vm.output }, set: { _ in }))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            HStack {
                Spacer()
                Button("Copy Output") { PasteboardHelper.copy(vm.output) }.disabled(vm.output.isEmpty)
            }
        }.padding(12)
    }

    // MARK: - Footer
    private var footer: some View {
        HStack {
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
            } else {
                Text("Băm chuỗi text hoặc file.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("Auto-Update", isOn: $vm.autoUpdate)
                .help("Tự động hash khi có thay đổi")
        }.padding(8)
    }
}
