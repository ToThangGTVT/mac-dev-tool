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
            }
        }
    }
}
