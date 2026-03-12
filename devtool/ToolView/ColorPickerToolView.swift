import SwiftUI
import AppKit

struct ColorPickerToolView: View {
    @State private var vm = ColorPickerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentBody
            Divider()
            footer
        }
        .navigationTitle("Color Picker & Converter")
        .frame(minWidth: 600, minHeight: 450)
    }
    
    private var header: some View {
        HStack {
            Text("Màu hiện tại:")
                .font(.headline)
            
            ColorPreview(color: vm.pickedNSColor)
                .frame(width: 80, height: 32)
            
            Spacer()
            
            Button { vm.pickFromScreen() } label: { Label("Pick from Screen", systemImage: "eyedropper.halffull") }
            .buttonStyle(.borderedProminent)
            
            ColorPicker("System Picker", selection: Binding(
                get: { Color(nsColor: vm.pickedNSColor) },
                set: { vm.pickedNSColor = NSColor($0) }
            ), supportsOpacity: vm.showAlpha)
            .labelsHidden()
            .frame(width: 40)
        }
        .padding()
    }
    
    private var contentBody: some View {
        HStack(spacing: 0) {
            VStack {
                ColorPreview(color: vm.pickedNSColor)
                RGBAEditor(
                    r: $vm.r, g: $vm.g, b: $vm.b, a: $vm.a,
                    showAlpha: vm.showAlpha
                )
                .padding(.top, 16)
                Spacer()
            }
            .padding()
            .frame(width: 280)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("HEX")
                            .font(.headline)
                            .frame(width: 50, alignment: .leading)
                        TextField("#RRGGBB", text: Binding(
                            get: { vm.hexInput },
                            set: { vm.hexInput = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 150)
                        
                        Toggle("Auto update", isOn: $vm.autoUpdate)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FormatRow(title: "HEX", value: vm.outHEX)
                        FormatRow(title: "RGB", value: vm.outRGB)
                        if vm.showAlpha { FormatRow(title: "RGBA", value: vm.outRGBA) }
                        
                        Divider().padding(.vertical, 4)
                        
                        FormatRow(title: "HSV / HSB", value: vm.outHSV)
                        FormatRow(title: "HSL", value: vm.outHSL)
                        if vm.showAlpha { FormatRow(title: "HSLA", value: vm.outHSLA) }
                        
                        Divider().padding(.vertical, 4)
                        
                        FormatRow(title: "CMYK", value: vm.outCMYK)
                        
                        Divider().padding(.vertical, 4)
                        
                        FormatRow(title: "SwiftUI Color", value: vm.outSwiftUIColor)
                        FormatRow(title: "NSColor", value: vm.outNSColor)
                    }
                }
                .padding()
            }
        }
        .frame(minHeight: 300)
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Text("Tùy chọn hiển thị HEX:").font(.subheadline).foregroundColor(.secondary)
            Toggle("Chữ HOA", isOn: $vm.hexUppercase)
            Toggle("Kèm dấu #", isOn: $vm.hexWithHash)
            Toggle("Kèm Alpha (8 chars)", isOn: $vm.showAlpha)
            Spacer()
        }
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .padding(8)
    }
}
