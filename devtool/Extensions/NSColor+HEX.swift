import AppKit

extension NSColor {
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
