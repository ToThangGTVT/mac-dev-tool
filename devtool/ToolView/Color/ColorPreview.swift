import SwiftUI

struct ColorPreview: View {
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

struct CheckerboardView: View {
    let squareSize: CGFloat
    let color1: Color
    let color2: Color
    
    private static var cachedImage: NSImage?
    private static var cachedKey: String = ""
    
    var body: some View {
        Color(nsColor: NSColor(patternImage: patternImage()))
    }
    
    private func patternImage() -> NSImage {
        let key = "\(squareSize)-\(color1)-\(color2)"
        if key == CheckerboardView.cachedKey, let img = CheckerboardView.cachedImage { return img }
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
        
        NSColor(color1).setFill()
        NSBezierPath(rect: rect).fill()
        
        NSColor(color2).setFill()
        let sq1 = CGRect(x: squareSize, y: 0, width: squareSize, height: squareSize)
        let sq2 = CGRect(x: 0, y: squareSize, width: squareSize, height: squareSize)
        NSBezierPath(rect: sq1).fill()
        NSBezierPath(rect: sq2).fill()
        
        image.unlockFocus()
        return image
    }
}
