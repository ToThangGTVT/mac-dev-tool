import SwiftUI
import AppKit

struct RSAKeyGeneratorView: View {
    @Bindable var vm: RSAViewModel

    var body: some View {
        GroupBox("Key Generator (RSA)") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Key size", selection: $vm.keySize) {
                        ForEach(RSAKeySize.allCases) { size in Text(size.label).tag(size) }
                    }
                    .frame(width: 180)
                    .disabled(vm.isGenerating)
                    
                    Spacer()
                    
                    Toggle("Autofill Keys to Inputs", isOn: $vm.autofillKeysToInputs)
                        .disabled(vm.isGenerating)

                    Button {
                        Task { await vm.generateRSAKeyPairAsync() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "key.horizontal")
                            }
                            Text(vm.isGenerating ? "Generating…" : "Generate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isGenerating)
                }

                // Nếu không autofill thì cho copy/save PEM tự do
                if !vm.autofillKeysToInputs {
                    Toggle("Hiển thị bản xem trước PEM", isOn: $vm.showPreview)
                        .disabled(vm.isGenerating)

                    if vm.showPreview, (!vm.generatedPrivatePEM.isEmpty || !vm.generatedPublicPEM.isEmpty) {
                        Divider().padding(.vertical, 2)

                        Text("Private Key (PEM)").font(.headline)
                        TextEditor(text: .constant(vm.generatedPrivatePEM))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            .disabled(true)

                        HStack(spacing: 8) {
                            Button { PasteboardHelper.copy(vm.generatedPrivatePEM) } label: {
                                Label("Copy Private", systemImage: "doc.on.doc")
                            }
                            Button { vm.savePEM(vm.generatedPrivatePEM, suggestedName: "rsa_private_\(vm.keySize.rawValue).pem") } label: {
                                Label("Save Private…", systemImage: "square.and.arrow.down")
                            }
                        }

                        Text("Public Key (PEM)").font(.headline).padding(.top, 6)
                        TextEditor(text: .constant(vm.generatedPublicPEM))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            .disabled(true)

                        HStack(spacing: 8) {
                            Button { PasteboardHelper.copy(vm.generatedPublicPEM) } label: {
                                Label("Copy Public", systemImage: "doc.on.doc")
                            }
                            Button { vm.savePEM(vm.generatedPublicPEM, suggestedName: "rsa_public_\(vm.keySize.rawValue).pem") } label: {
                                Label("Save Public…", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
                }
            }
        }
    }
}
