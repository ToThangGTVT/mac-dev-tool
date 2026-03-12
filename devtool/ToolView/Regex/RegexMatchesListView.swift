import SwiftUI

struct RegexMatchesListView: View {
    let matches: [RegexMatchInfo]
    
    var body: some View {
        if matches.isEmpty {
            VStack {
                Spacer()
                Text("No matches yet").foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(matches.enumerated().map({$0}), id: \.element.range.location) { idx, match in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Match #\(idx + 1)")
                            .font(.headline)
                        Text("[\(match.range.location)..<\(match.range.location + match.range.length))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    Text(match.substring)
                        .font(.system(.body, design: .monospaced))
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                    
                    if !match.groups.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Groups:").font(.subheadline).foregroundColor(.secondary)
                            ForEach(match.groups, id: \.index) { g in
                                HStack(alignment: .top) {
                                    Text(g.name ?? "#\(g.index)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(Color(groupColor(for: g.index)))
                                        .frame(width: 80, alignment: .trailing)
                                    Text("[\(g.range.location)..<\(g.range.location + g.range.length))]")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 100, alignment: .leading)
                                        .textSelection(.enabled)
                                    Text(g.value ?? "nil")
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }
    
    private let groupPalette: [NSColor] = [
        .systemBlue, .systemGreen, .systemPink, .systemOrange,
        .systemPurple, .systemTeal, .systemIndigo, .systemMint,
        .systemBrown, .systemRed
    ]
    private func groupColor(for index: Int) -> NSColor {
        let i = max(0, index - 1)
        return groupPalette[i % groupPalette.count]
    }
}
