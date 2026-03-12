import SwiftUI

struct RSAInspectorView: View {
    @Bindable var vm: RSAViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output").font(.headline)
                Spacer()
                Button { PasteboardHelper.copy(vm.outputText) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(vm.outputText.isEmpty)
            }

            TextEditor(text: .constant(vm.outputText))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .disabled(true)

            if let e = vm.errorMessage, !e.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(e).foregroundColor(.secondary)
                }
            } else { Text(" ").hidden() }

            HStack {
                Button("Copy Output") { PasteboardHelper.copy(vm.outputText) }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.outputText.isEmpty)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
