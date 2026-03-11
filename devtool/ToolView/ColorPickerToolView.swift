//
//  ColorPickerToolView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct ColorPickerToolView: View {
    // MARK: - Settings
    @AppStorage("color.hexUppercase") private var hexUppercase: Bool = true
    @AppStorage("color.hexWithHash")  private var hexWithHash: Bool = true
    @AppStorage("color.showAlpha")    private var showAlpha: Bool = true
    @AppStorage("color.autoUpdate")   private var autoUpdate: Bool = true
    @State private var showInspector: Bool = true
    
    // MARK: - State
    @State private var pickedNSColor: NSColor = NSColor(srgbRed: 0.2, green: 0.45, blue: 0.9, alpha: 1.0)
    
    @State private var hexInput: String = "#3A74E6"
    @State private var errorMessage: String?
    @State private var isPicking: Bool = false
    
    // Derived formats (rendered mỗi lần color đổi)
    @State private var outHEX: String = ""
    @State private var outRGB: String = ""
    @State private var outRGBA: String = ""
    @State private var outHSL: String = ""
    @State private var outHSLA: String = ""
    @State private var outHSV: String = ""
    @State private var outCMYK: String = ""
    @State private var outSwiftUIColor: String = ""
    @State private var outNSColor: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("Color Picker + Converter")
        .toolbar {
            ToolbarItemGroup {
                Button { pickFromScreen() } label: {
                    Label(isPicking ? "Picking…" : "Pick from Screen", systemImage: "eyedropper.halffull")
                }
                .disabled(isPicking)
                
                Button { openSystemColorPanel() } label: {
                    Label("Open Color Panel", systemImage: "paintpalette")
                }
                
                Button { syncFromNSColorPanel() } label: {
                    Label("Use Panel Color", systemImage: "arrow.down.left.and.arrow.up.right")
                }
                
                Button(role: .destructive) { clearAll() } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Spacer()
                
                Button { withAnimation { showInspector.toggle() } } label: {
                    Label("Toggle Preview", systemImage: "sidebar.trailing")
                }
                .help("Toggle Preview Sidebar")
            }
        }
        .inspector(isPresented: $showInspector) {
            inspectorContent
                .inspectorColumnWidth(min: 260, ideal: 350, max: 500)
        }
        .onAppear {
            recalcAll()
        }
        .onChange(of: pickedNSColor) { _ in queueRecalcAll() }
        .onChange(of: showAlpha) { _ in queueRecalcAll() }
        .onChange(of: hexUppercase) { _ in queueRecalcAll() }
        .onChange(of: hexWithHash) { _ in queueRecalcAll() }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Toggle("Hiển thị Alpha (A)", isOn: $showAlpha)
                Toggle("HEX Uppercase", isOn: $hexUppercase)
                Toggle("HEX có #", isOn: $hexWithHash)
                Spacer()
            }
            .padding(.horizontal, 12)
            
            HStack(spacing: 12) {
                Text("HEX")
                    .font(.headline)
                TextField("#RRGGBB hoặc #RRGGBBAA", text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { applyHEXInput() }
                Button("Apply") { applyHEXInput() }
                    .buttonStyle(.borderedProminent)
                Button("Paste") { pasteHEX() }
                Button("Copy HEX") { copyToPasteboard(outHEX) }
                    .disabled(outHEX.isEmpty)
                if let err = errorMessage, !err.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                        Text(err).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Content
    // Bindings cho RGBA sliders — tính 1 lần, không tạo closure mới mỗi body evaluation
    private var rBinding: Binding<CGFloat> {
        Binding(
            get: { rgba01(from: pickedNSColor).r },
            set: { newR in
                let c = rgba01(from: pickedNSColor)
                pickedNSColor = NSColor(srgbRed: newR, green: c.g, blue: c.b, alpha: c.a)
                if autoUpdate { syncHEXFromColor() }
            }
        )
    }
    private var gBinding: Binding<CGFloat> {
        Binding(
            get: { rgba01(from: pickedNSColor).g },
            set: { newG in
                let c = rgba01(from: pickedNSColor)
                pickedNSColor = NSColor(srgbRed: c.r, green: newG, blue: c.b, alpha: c.a)
                if autoUpdate { syncHEXFromColor() }
            }
        )
    }
    private var bBinding: Binding<CGFloat> {
        Binding(
            get: { rgba01(from: pickedNSColor).b },
            set: { newB in
                let c = rgba01(from: pickedNSColor)
                pickedNSColor = NSColor(srgbRed: c.r, green: c.g, blue: newB, alpha: c.a)
                if autoUpdate { syncHEXFromColor() }
            }
        )
    }
    private var aBinding: Binding<CGFloat> {
        Binding(
            get: { rgba01(from: pickedNSColor).a },
            set: { newA in
                let c = rgba01(from: pickedNSColor)
                pickedNSColor = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: newA)
                if autoUpdate { syncHEXFromColor() }
            }
        )
    }
    
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Formats").font(.headline)
                
                FormatRow(title: "HEX", value: outHEX, copyable: true)
                FormatRow(title: "RGB", value: outRGB, copyable: true)
                FormatRow(title: "RGBA", value: outRGBA, copyable: true)
                FormatRow(title: "HSL", value: outHSL, copyable: true)
                FormatRow(title: "HSLA", value: outHSLA, copyable: true)
                FormatRow(title: "HSV", value: outHSV, copyable: true)
                FormatRow(title: "CMYK", value: outCMYK, copyable: true)
                
                Divider().padding(.vertical, 4)
                Text("Code Snippets").font(.headline)
                FormatRow(title: "SwiftUI Color", value: outSwiftUIColor, copyable: true)
                FormatRow(title: "NSColor (sRGB)", value: outNSColor, copyable: true)
                
                Spacer()
            }
            .padding(12)
        }
    }
        
    // MARK: - Inspector (Preview Sidebar)
    private var inspectorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview").font(.headline)
                ColorPreview(color: pickedNSColor)
                    .frame(height: 140)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .drawingGroup()
                
                // RGBA sliders
                RGBAEditor(r: rBinding, g: gBinding, b: bBinding, a: aBinding, showAlpha: showAlpha)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Button("Pick from Screen", action: pickFromScreen)
                        .buttonStyle(.borderedProminent)
                        .disabled(isPicking)
                        .frame(maxWidth: .infinity)
                    Button("Open Color Panel", action: openSystemColorPanel)
                        .frame(maxWidth: .infinity)
                    Button("Use Panel Color", action: syncFromNSColorPanel)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding(12)
        }
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 10) {
            Text("Pick bằng NSColorSampler (không cần quyền). Live capture cần Screen Recording.")
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(8)
    }
    
    // MARK: - Actions
    private func applyHEXInput() {
        errorMessage = nil
        let s = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = NSColor.fromHEX(s) else {
            errorMessage = "HEX không hợp lệ. Dùng #RRGGBB hoặc #RRGGBBAA."
            return
        }
        pickedNSColor = c
        recalcAll()
    }
    private func pasteHEX() {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string) {
            hexInput = s
            applyHEXInput()
        }
    }
    private func clearAll() {
        hexInput = ""
        errorMessage = nil
    }
    
    private func pickFromScreen() {
        guard #available(macOS 10.15, *) else {
            errorMessage = "NSColorSampler yêu cầu macOS 10.15+."
            return
        }
        isPicking = true
        let sampler = NSColorSampler()
        sampler.show { nsColor in
            self.isPicking = false
            guard let color = nsColor else { return } // user canceled
            self.pickedNSColor = color.usingColorSpace(.sRGB) ?? color
            self.syncHEXFromColor()
            self.recalcAll()
        }
    }
    private func openSystemColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func syncFromNSColorPanel() {
        let panel = NSColorPanel.shared
        let c = panel.color.usingColorSpace(.sRGB) ?? panel.color
        pickedNSColor = c
        syncHEXFromColor()
        recalcAll()
    }
    
    // MARK: - Compute & format
    // Removed synchronous recalcAll during every NSColor slider change.
    
    // Khai báo một property để lưu Timer hoặc cơ chế debounce (có sẵn hoặc debounce đơn giản)
    @State private var recalcTask: DispatchWorkItem?
    
    private func queueRecalcAll() {
        recalcTask?.cancel()
        
        let task = DispatchWorkItem {
            self.recalcAll()
        }
        recalcTask = task
        
        // Debounce: Chờ 0.15 giây sau khi hết kéo slider mới tính khối text khổng lồ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }
    
    private func recalcAll() {
        let c = pickedNSColor.usingColorSpace(.sRGB) ?? pickedNSColor
        let rgba = rgba01(from: c)
        outHEX  = toHEX(rgba, includeHash: hexWithHash, uppercase: hexUppercase, includeAlpha: showAlpha)
        outRGB  = "rgb(\(Int(rgba.r*255)), \(Int(rgba.g*255)), \(Int(rgba.b*255)))"
        outRGBA = "rgba(\(Int(rgba.r*255)), \(Int(rgba.g*255)), \(Int(rgba.b*255)), \(round2(rgba.a)))"
        
        let hsb = hsb01(from: c)
        let hsl = hsl01(fromRGB: rgba)
        outHSV  = "hsv(\(roundInt(hsb.h*360))°, \(roundInt(hsb.s*100))%, \(roundInt(hsb.b*100))%)"
        outHSL  = "hsl(\(roundInt(hsl.h*360))°, \(roundInt(hsl.s*100))%, \(roundInt(hsl.l*100))%)"
        outHSLA = "hsla(\(roundInt(hsl.h*360))°, \(roundInt(hsl.s*100))%, \(roundInt(hsl.l*100))%, \(round2(rgba.a)))"
        
        let cmyk = cmyk01(fromRGB: rgba)
        outCMYK = "cmyk(\(roundInt(cmyk.c*100))%, \(roundInt(cmyk.m*100))%, \(roundInt(cmyk.y*100))%, \(roundInt(cmyk.k*100))%)"
        
        outSwiftUIColor = String(format: "Color(red: %.3f, green: %.3f, blue: %.3f, opacity: %.3f)", rgba.r, rgba.g, rgba.b, rgba.a)
        outNSColor = String(format: "NSColor(srgbRed: %.3f, green: %.3f, blue: %.3f, alpha: %.3f)", rgba.r, rgba.g, rgba.b, rgba.a)
        
        if autoUpdate { hexInput = outHEX }
    }
    private func syncHEXFromColor() {
        let rgba = rgba01(from: pickedNSColor.usingColorSpace(.sRGB) ?? pickedNSColor)
        hexInput = toHEX(rgba, includeHash: hexWithHash, uppercase: hexUppercase, includeAlpha: showAlpha)
    }
    
    private func copyToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
    
    // MARK: - Math & conversions
    private func rgba01(from c: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let sc = c.usingColorSpace(.sRGB) ?? c
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        sc.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    private func hsb01(from c: NSColor) -> (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        let sc = c.usingColorSpace(.sRGB) ?? c
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 1
        sc.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return (h, s, br, a)
    }
    private func hsl01(fromRGB rgb: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        let r = rgb.r, g = rgb.g, b = rgb.b
        let maxV = max(r, g, b), minV = min(r, g, b)
        var h: CGFloat = 0, s: CGFloat = 0
        let l = (maxV + minV) / 2
        let d = maxV - minV
        if d != 0 {
            s = d / (1 - abs(2*l - 1))
            if maxV == r {
                h = ( (g - b) / d ).truncatingRemainder(dividingBy: 6)
            } else if maxV == g {
                h = ( (b - r) / d ) + 2
            } else {
                h = ( (r - g) / d ) + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        } else {
            h = 0; s = 0
        }
        return (h, s, l)
    }
    private func cmyk01(fromRGB rgb: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> (c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat) {
        let r = rgb.r, g = rgb.g, b = rgb.b
        let k = 1 - max(r, g, b)
        if k >= 0.9999 { return (0, 0, 0, 1) }
        let c = (1 - r - k) / (1 - k)
        let m = (1 - g - k) / (1 - k)
        let y = (1 - b - k) / (1 - k)
        return (c, m, y, k)
    }
    private func toHEX(_ rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat), includeHash: Bool, uppercase: Bool, includeAlpha: Bool) -> String {
        let R = Int(round(rgba.r * 255))
        let G = Int(round(rgba.g * 255))
        let B = Int(round(rgba.b * 255))
        let A = Int(round(rgba.a * 255))
        var s: String
        if includeAlpha {
            s = String(format: "%02X%02X%02X%02X", R, G, B, A)
        } else {
            s = String(format: "%02X%02X%02X", R, G, B)
        }
        if !uppercase { s = s.lowercased() }
        return includeHash ? "#"+s : s
    }
    private func round2(_ x: CGFloat) -> String {
        String(format: "%.2f", x)
    }
    private func roundInt(_ x: CGFloat) -> Int {
        Int(round(x))
    }
}

// MARK: - Subviews

/// Khung swatch với nền caro (checkerboard) để nhìn alpha
fileprivate struct ColorPreview: View {
    let color: NSColor
    var body: some View {
        ZStack {
            CheckerboardView(squareSize: 10, color1: .white, color2: .gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Color(nsColor: color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        }
    }
}

fileprivate struct CheckerboardView: View {
    let squareSize: CGFloat
    let color1: Color
    let color2: Color
    
    // Cache pattern image — chỉ tạo 1 lần, không tạo lại mỗi body evaluation khi resize
    private static var cachedImage: NSImage?
    private static var cachedKey: String = ""
    
    var body: some View {
        Color(nsColor: NSColor(patternImage: patternImage()))
    }
    
    private func patternImage() -> NSImage {
        // Build a key from the parameters so we only regenerate when they change
        let key = "\(squareSize)-\(color1)-\(color2)"
        if key == CheckerboardView.cachedKey, let img = CheckerboardView.cachedImage {
            return img
        }
        let img = createPatternImage()
        CheckerboardView.cachedImage = img
        CheckerboardView.cachedKey = key
        return img
    }
    
    private func createPatternImage() -> NSImage {
        let size = CGSize(width: squareSize * 2, height: squareSize * 2)
        let rect = CGRect(origin: .zero, size: size)
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor(color1).setFill()
        NSBezierPath(rect: rect).fill()
        
        // Checker squares
        NSColor(color2).setFill()
        let sq1 = CGRect(x: squareSize, y: 0, width: squareSize, height: squareSize)
        let sq2 = CGRect(x: 0, y: squareSize, width: squareSize, height: squareSize)
        NSBezierPath(rect: sq1).fill()
        NSBezierPath(rect: sq2).fill()
        
        image.unlockFocus()
        return image
    }
}

/// Hàng hiển thị một format + nút Copy — dùng Text thay TextField để tránh relayout khi resize
fileprivate struct FormatRow: View {
    let title: String
    let value: String
    var copyable: Bool = true
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.headline)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            if copyable {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(value, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(value.isEmpty)
            }
        }
    }
}

/// Editor sliders cho RGBA (0...1)
fileprivate struct RGBAEditor: View {
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
                set: { newV in
                    value.wrappedValue = CGFloat(newV)
                }
            ), in: 0...1)
            .tint(tint)
            Text(String(format: "%.0f", value.wrappedValue * 255))
                .frame(width: 36, alignment: .trailing)
            Text(String(format: "%.2f", value.wrappedValue))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - NSColor + HEX parsing
fileprivate extension NSColor {
    static func fromHEX(_ str: String) -> NSColor? {
        var s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let chars = Array(s)
        func hexByte(_ a: Character, _ b: Character) -> CGFloat? {
            guard let v = UInt8(String([a,b]), radix: 16) else { return nil }
            return CGFloat(v) / 255.0
        }
        switch chars.count {
        case 6: // RRGGBB
            guard let r = hexByte(chars[0], chars[1]),
                  let g = hexByte(chars[2], chars[3]),
                  let b = hexByte(chars[4], chars[5]) else { return nil }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        case 8: // RRGGBBAA
            guard let r = hexByte(chars[0], chars[1]),
                  let g = hexByte(chars[2], chars[3]),
                  let b = hexByte(chars[4], chars[5]),
                  let a = hexByte(chars[6], chars[7]) else { return nil }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }
}
