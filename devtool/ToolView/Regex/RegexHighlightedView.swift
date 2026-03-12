import SwiftUI
import AppKit

struct RegexHighlightedView: View {
    let highlightedNS: NSAttributedString
    
    var body: some View {
        ScrollView(.vertical) {
            ScrollView(.horizontal) {
                Text(AttributedString(highlightedNS))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
    }
}
