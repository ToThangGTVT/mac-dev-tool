import SwiftUI

struct Base64InspectorView: View {
    @Bindable var vm: Base64ViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cấu hình Base64")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chế độ").font(.subheadline).foregroundColor(.secondary)
                        Picker("Chế độ", selection: $vm.mode) {
                            ForEach(Base64Mode.allCases) { m in Text(m.rawValue).tag(m) }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wrap").font(.subheadline).foregroundColor(.secondary)
                        Picker("Wrap", selection: $vm.wrap) {
                            ForEach(Base64Wrap.allCases) { w in Text(w.rawValue).tag(w) }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Line Ending").font(.subheadline).foregroundColor(.secondary)
                        Picker("Line Ending", selection: $vm.lineEnding) {
                            ForEach(Base64LineEnding.allCases) { le in Text(le.rawValue).tag(le) }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Encoding").font(.subheadline).foregroundColor(.secondary)
                        Picker("Encoding", selection: $vm.stringEncoding) {
                            ForEach(TextEncoding.allCases) { enc in Text(enc.rawValue).tag(enc) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
