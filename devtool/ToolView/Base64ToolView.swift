import SwiftUI
internal import UniformTypeIdentifiers

struct Base64ToolView: View {
    @State private var vm = Base64ViewModel()
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            bodyEditors
            Divider()
            footer
        }
        .navigationTitle("Base64")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    vm.performMainAction()
                } label: {
                    Label(vm.mode == .encode ? "Encode" : "Decode",
                          systemImage: vm.mode == .encode ? "arrow.up.square" : "arrow.down.square")
                }
                .keyboardShortcut(.return)
                
                Button {
                    vm.swapMode()
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                
                Button {
                    PasteboardHelper.copy(vm.output)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(vm.output.isEmpty)
                
                Button {
                    if let text = PasteboardHelper.paste() {
                        vm.input = text
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                
                Button(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Picker("Chế độ", selection: $vm.mode) {
                ForEach(Base64Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Divider().frame(height: 22)
            
            Picker("Wrap", selection: $vm.wrap) {
                ForEach(Base64Wrap.allCases) { w in Text(w.rawValue).tag(w) }
            }
            .frame(width: 120)
            
            Picker("Line Ending", selection: $vm.lineEnding) {
                ForEach(Base64LineEnding.allCases) { le in Text(le.rawValue).tag(le) }
            }
            .frame(width: 180)
            
            Picker("Encoding", selection: $vm.stringEncoding) {
                ForEach(TextEncoding.allCases) { enc in Text(enc.rawValue).tag(enc) }
            }
            .frame(width: 140)
            
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Editors
    private var bodyEditors: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input").font(.headline)
                    Spacer()
                    Button { vm.input = "" } label: { Image(systemName: "xmark.circle").foregroundColor(.secondary) }
                    .buttonStyle(.borderless).help("Clear input")
                }
                
                TextEditor(text: $vm.input)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                        DropHandler.handleTextDrop(providers: providers) { text in
                            vm.input = text
                        }
                    }
                
                HStack(spacing: 8) {
                    Button(vm.mode == .encode ? "Encode" : "Decode", action: vm.performMainAction).buttonStyle(.borderedProminent)
                    Button("Swap Mode", action: vm.swapMode)
                    Button("Paste") { if let text = PasteboardHelper.paste() { vm.input = text } }
                    Spacer()
                    Button("Clear", role: .destructive, action: vm.clearAll)
                }
            }
            .padding(12)
            .frame(minWidth: 420)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output").font(.headline)
                    Spacer()
                    Button { PasteboardHelper.copy(vm.output) } label: { Image(systemName: "doc.on.doc").foregroundColor(.secondary) }
                    .buttonStyle(.borderless).help("Copy output")
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
            }
            .padding(12)
            .frame(minWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
                if err.contains("Decode") && vm.mode == .encode {
                    Button("Chuyển sang Decode") { vm.mode = .decode }
                }
            } else {
                Text(vm.mode == .encode ? "Encode chuỗi văn bản thành Base64." : "Decode Base64 thành chuỗi văn bản.")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
    }
}
