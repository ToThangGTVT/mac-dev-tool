import SwiftUI

struct RSAInputFormView: View {
    @Bindable var vm: RSAViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                HStack {
                    Text("Public Key (PEM)").font(.headline)
                    Spacer()
                    if vm.operation == .encrypt || vm.operation == .verify {
                        Text("Cần PUBLIC KEY").foregroundColor(.secondary)
                    }
                }
                TextEditor(text: $vm.publicKeyPEM)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))

                HStack {
                    Text("Private Key (PEM)").font(.headline)
                    Spacer()
                    if vm.operation == .decrypt || vm.operation == .sign {
                        Text("Cần PRIVATE KEY").foregroundColor(.secondary)
                    }
                }
                TextEditor(text: $vm.privateKeyPEM)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            Group {
                if vm.operation == .encrypt || vm.operation == .sign || vm.operation == .verify {
                    HStack {
                        Text(vm.operation == .verify ? "Message (để verify)" : "Message")
                            .font(.headline)
                        Spacer()
                        Button { vm.messageText = "" } label: {
                            Image(systemName: "xmark.circle").foregroundColor(.secondary)
                        }.buttonStyle(.borderless)
                    }
                    TextEditor(text: $vm.messageText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 110)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }

                if vm.operation == .decrypt || vm.operation == .verify {
                    HStack {
                        Text(vm.operation == .decrypt ? "Ciphertext (\(vm.binFormat.rawValue))" : "Signature (\(vm.binFormat.rawValue))")
                            .font(.headline)
                        Spacer()
                        Button { vm.binaryInput = "" } label: {
                            Image(systemName: "xmark.circle").foregroundColor(.secondary)
                        }.buttonStyle(.borderless)
                    }
                    TextEditor(text: $vm.binaryInput)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }
}
