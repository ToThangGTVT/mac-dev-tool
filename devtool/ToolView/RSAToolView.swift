import SwiftUI
import AppKit

struct RSAToolView: View {
    @State private var vm = RSAViewModel()
    @State private var showInspector: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            editors
            Divider()
            footer
        }
        .navigationTitle("RSA (Encrypt / Decrypt / Sign / Verify) + KeyGen")
        .toolbar {
            ToolbarItemGroup {
                Button(action: vm.runAction) {
                    Label(actionTitle, systemImage: "play.circle")
                }
                .keyboardShortcut(.return)

                Button { PasteboardHelper.copy(vm.outputText) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(vm.outputText.isEmpty)

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
                .help("Toggle Results Sidebar")
            }
        }
        .padding(.bottom, 4)
        .inspector(isPresented: $showInspector) {
            RSAInspectorView(vm: vm)
                .inspectorColumnWidth(min: 250, ideal: 300, max: 600)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var editors: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RSAInputFormView(vm: vm)
                
                HStack(spacing: 8) {
                    Button(actionTitle, action: vm.runAction).buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Clear", role: .destructive, action: vm.clearAll)
                }
            }.padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var footer: some View {
        HStack {
            Text(footerHelp).foregroundColor(.secondary).font(.callout)
            Spacer()
        }.padding(8)
    }
    
    private var footerHelp: String {
        switch vm.operation {
        case .encrypt: return "Encrypt: dùng PUBLIC KEY. OAEP an toàn hơn PKCS#1 v1.5. Plaintext phải nhỏ hơn modulus."
        case .decrypt: return "Decrypt: dùng PRIVATE KEY. Chọn đúng thuật toán (PKCS#1 hoặc OAEP SHA‑1/SHA‑256)."
        case .sign: return "Sign: dùng PRIVATE KEY. PSS an toàn hơn PKCS#1 v1.5. Output là chữ ký (Base64/Hex)."
        case .verify: return "Verify: dùng PUBLIC KEY, nhập message + signature (Base64/Hex)."
        }
    }
    
    private var actionTitle: String {
        switch vm.operation {
        case .encrypt: return "Encrypt"
        case .decrypt: return "Decrypt"
        case .sign:    return "Sign"
        case .verify:  return "Verify"
        }
    }
}
