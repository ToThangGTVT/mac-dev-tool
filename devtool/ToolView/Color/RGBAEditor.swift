import SwiftUI

struct RGBAEditor: View {
    @Binding var r: CGFloat
    @Binding var g: CGFloat
    @Binding var b: CGFloat
    @Binding var a: CGFloat
    let showAlpha: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sliderRow("R", value: $r, tint: .red)
            sliderRow("G", value: $g, tint: .green)
            sliderRow("B", value: $b, tint: .blue)
            if showAlpha {
                sliderRow("A", value: $a, tint: .gray)
            }
        }
    }
    
    private func sliderRow(_ name: String, value: Binding<CGFloat>, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(name).frame(width: 18, alignment: .leading)
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = CGFloat($0) }
            ), in: 0...1)
            .tint(tint)
            Text(String(format: "%.0f", value.wrappedValue * 255))
                .font(.system(.body, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
        }
    }
}
