import Foundation
import AppKit

@Observable
class ColorPickerViewModel {
    var pickedNSColor: NSColor = .systemBlue { didSet { queueRecalcAll() } }
    var autoUpdate: Bool { didSet { save("color.autoUpdate", autoUpdate); queueRecalcAll() } }
    var hexUppercase: Bool { didSet { save("color.hexUpper", hexUppercase); queueRecalcAll() } }
    var hexWithHash: Bool { didSet { save("color.hexHash", hexWithHash); queueRecalcAll() } }
    var showAlpha: Bool { didSet { save("color.showAlpha", showAlpha); queueRecalcAll() } }
    
    var hexInput: String = "" {
        didSet {
            if let c = NSColor.fromHEX(hexInput) {
                if c != pickedNSColor { pickedNSColor = c }
            }
        }
    }
    
    var outHEX: String = ""
    var outRGB: String = ""
    var outRGBA: String = ""
    var outHSV: String = ""
    var outHSL: String = ""
    var outHSLA: String = ""
    var outCMYK: String = ""
    var outSwiftUIColor: String = ""
    var outNSColor: String = ""
    
    // Sliders support (0...1)
    var r: CGFloat = 0 { didSet { updateFromRGBA() } }
    var g: CGFloat = 0 { didSet { updateFromRGBA() } }
    var b: CGFloat = 1 { didSet { updateFromRGBA() } }
    var a: CGFloat = 1 { didSet { updateFromRGBA() } }
    private var isUpdatingFromSliders = false
    
    var recalculateCount = 0 // for debounce trigger
    
    init() {
        self.autoUpdate = Self.loadBoolDefaultTrue("color.autoUpdate")
        self.hexUppercase = Self.loadBoolDefaultTrue("color.hexUpper")
        self.hexWithHash = Self.loadBoolDefaultTrue("color.hexHash")
        self.showAlpha = Self.loadBoolDefaultTrue("color.showAlpha")
        queueRecalcAll()
    }
    
    private func save(_ key: String, _ value: Bool) { UserDefaults.standard.set(value, forKey: key) }
    private static func loadBoolDefaultTrue(_ key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func updateFromRGBA() {
        guard !isUpdatingFromSliders else { return }
        pickedNSColor = NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    
    private var recalcTask: DispatchWorkItem?
    
    func queueRecalcAll() {
        recalcTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.recalcAll()
        }
        recalcTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
    }
    
    func recalcAll() {
        let c = pickedNSColor.usingColorSpace(.sRGB) ?? pickedNSColor
        let rgba = rgba01(from: c)
        
        // Sync sliders without triggering recursive update
        isUpdatingFromSliders = true
        r = rgba.r; g = rgba.g; b = rgba.b; a = rgba.a
        isUpdatingFromSliders = false
        
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
        
        if autoUpdate && hexInput != outHEX {
            hexInput = outHEX
        }
    }
    
    func pickFromScreen() {
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            if let color = selectedColor {
                self?.pickedNSColor = color
            }
        }
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
            if maxV == r { h = ( (g - b) / d ).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = ( (b - r) / d ) + 2 }
            else { h = ( (r - g) / d ) + 4 }
            h /= 6
            if h < 0 { h += 1 }
        } else { h = 0; s = 0 }
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
        if includeAlpha { s = String(format: "%02X%02X%02X%02X", R, G, B, A) }
        else { s = String(format: "%02X%02X%02X", R, G, B) }
        if !uppercase { s = s.lowercased() }
        return includeHash ? "#"+s : s
    }
    private func round2(_ x: CGFloat) -> String { String(format: "%.2f", x) }
    private func roundInt(_ x: CGFloat) -> Int { Int(round(x)) }
}
