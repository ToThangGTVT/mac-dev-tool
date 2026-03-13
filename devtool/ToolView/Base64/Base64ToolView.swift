import SwiftUI
internal import UniformTypeIdentifiers

struct Base64ToolView: View {
    @State private var vm = Base64ViewModel()
    @State private var isTargeted: Bool = false
    @State private var showInspector: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
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

                Spacer()

                Button { withAnimation { showInspector.toggle() } } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.trailing")
                }
                .help("Toggle Configuration Sidebar")
            }
        }
        .padding(.bottom, 4)
        .inspector(isPresented: $showInspector) {
            Base64InspectorView(vm: vm)
                .inspectorColumnWidth(min: 250, ideal: 300, max: 450)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Label("Configuration", systemImage: "gearshape")
                .font(.headline)
            
            Text(vm.mode.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)

            Text(vm.stringEncoding.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Editors
    private var bodyEditors: some View {
        VStack(spacing: 0) {
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
