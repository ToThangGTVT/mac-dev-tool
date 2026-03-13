import SwiftUI

struct Base64InspectorView: View {
    @Bindable var vm: Base64ViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Thuật toán / Algorithm
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thuật toán").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $vm.algorithm) {
                            ForEach(UnifiedAlgorithm.allCases) { alg in Text(alg.rawValue).tag(alg) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Chế độ / Mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chế độ").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $vm.mode) {
                            Text("Encode").tag(Base64Mode.encode)
                            Text(vm.algorithm.isHash ? "Verify" : "Decode").tag(Base64Mode.decode)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if vm.algorithm == .base64 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wrap").font(.subheadline).foregroundColor(.secondary)
                            Picker("", selection: $vm.wrap) {
                                ForEach(Base64Wrap.allCases) { w in Text(w.rawValue).tag(w) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Line Ending").font(.subheadline).foregroundColor(.secondary)
                            Picker("", selection: $vm.lineEnding) {
                                ForEach(Base64LineEnding.allCases) { le in Text(le.rawValue).tag(le) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hash Output Format").font(.subheadline).foregroundColor(.secondary)
                            Picker("", selection: $vm.hashOutputFormat) {
                                ForEach(HashOutputFormat.allCases) { fmt in Text(fmt.rawValue).tag(fmt) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text Encoding").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $vm.stringEncoding) {
                            ForEach(TextEncoding.allCases) { enc in Text(enc.rawValue).tag(enc) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

