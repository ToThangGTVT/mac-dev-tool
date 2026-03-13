import SwiftUI

struct RSAInspectorView: View {
    @Bindable var vm: RSAViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RSAKeyGeneratorView(vm: vm)
                    .padding(.top, 8)
                
                Divider()

                Text("Settings")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Operation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Operation").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $vm.operation) {
                            ForEach(RSAOperation.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Algorithm
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Algorithm").font(.subheadline).foregroundColor(.secondary)
                        if vm.operation == .encrypt || vm.operation == .decrypt {
                            Picker("", selection: $vm.encAlg) {
                                ForEach(RSAEncryptAlg.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Picker("", selection: $vm.sigAlg) {
                                ForEach(RSASignAlg.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Message Encoding
                    if vm.operation == .encrypt || vm.operation == .sign || vm.operation == .verify {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message Encoding").font(.subheadline).foregroundColor(.secondary)
                            Picker("", selection: $vm.msgEncoding) {
                                ForEach(TextEncoding.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Binary Format
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Binary Format").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $vm.binFormat) {
                            ForEach(RSABinaryFormat.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help("Định dạng vào/ra cho ciphertext hoặc signature")
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Output").font(.headline)
                        Spacer()
                        Button { PasteboardHelper.copy(vm.outputText) } label: {
                            Image(systemName: "doc.on.doc").foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(vm.outputText.isEmpty)
                        .help("Copy output")
                    }

                    TextEditor(text: .constant(vm.outputText))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .disabled(true)

                    if let e = vm.errorMessage, !e.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                            Text(e).foregroundColor(.secondary).font(.caption)
                        }
                    }

                    HStack {
                        Button("Copy Output") { PasteboardHelper.copy(vm.outputText) }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.outputText.isEmpty)
                            .controlSize(.small)
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
