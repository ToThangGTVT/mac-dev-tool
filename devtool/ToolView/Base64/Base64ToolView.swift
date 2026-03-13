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
        .navigationTitle(vm.algorithm.rawValue)
        .toolbar {
            ToolbarItemGroup {
                Button { vm.performMainAction() } label: { 
                    Label(vm.algorithm == .base64 ? (vm.mode == .encode ? "Encode" : "Decode") : (vm.mode == .encode ? "Hash" : "Verify"),
                          systemImage: vm.algorithm == .base64 ? (vm.mode == .encode ? "arrow.up.square" : "arrow.down.square") : (vm.mode == .encode ? "shield.checkerboard" : "checkmark.shield"))
                }
                .keyboardShortcut(.return)
                
                if vm.algorithm == .base64 {
                    Button { vm.swapMode() } label: { Label("Swap", systemImage: "arrow.left.arrow.right") }
                }
                
                Button { PasteboardHelper.copy(vm.output) } label: { Label("Copy", systemImage: "doc.on.doc") }
                .disabled(vm.output.isEmpty)
                
                Button { if let text = PasteboardHelper.paste() { vm.input = text } } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                
                Button(role: .destructive) { vm.clearAll() } label: { Label("Clear", systemImage: "trash") }
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
    
    // MARK: - Editors
    private var bodyEditors: some View {
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
            
            if vm.algorithm.isHash && vm.mode == .decode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Hash (to compare)").font(.headline)
                    TextField("Paste hash here...", text: $vm.targetHash)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            HStack(spacing: 8) {
                if vm.algorithm == .base64 {
                    Button(vm.mode == .encode ? "Encode" : "Decode", action: vm.performMainAction).buttonStyle(.borderedProminent)
                    Button("Swap Mode", action: vm.swapMode)
                } else {
                    Button(vm.mode == .encode ? "Hash" : "Verify", action: vm.performMainAction).buttonStyle(.borderedProminent)
                }
                Button("Paste") { if let text = PasteboardHelper.paste() { vm.input = text } }.disabled(vm.droppedFileURL != nil)
                Spacer()
                Button("Clear", role: .destructive, action: vm.clearAll)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
            } else {
                Text(vm.algorithm == .base64 ?
                     (vm.mode == .encode ? "Chuyển dữ liệu sang Base64." : "Chuyển Base64 sang dữ liệu.") :
                     "Băm dữ liệu bằng thuật toán \(vm.algorithm.rawValue).")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
    }
}
