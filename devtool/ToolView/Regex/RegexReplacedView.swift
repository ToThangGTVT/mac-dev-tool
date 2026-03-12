import SwiftUI

struct RegexReplacedView: View {
    let replacedOutput: String
    
    var body: some View {
        TextEditor(text: .constant(replacedOutput))
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            .padding(8)
    }
}
