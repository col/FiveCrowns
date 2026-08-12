import SwiftUI

struct ScoreCell: View {
    let points: Int?
    let playerName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(points.map(String.init) ?? "-")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.medium)
                .frame(minWidth: 44)
                .padding(8)
                .border(points == nil ? Color.gray : Color.accentColor)
                .background(points == 0 ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Score for \(playerName)")
        .accessibilityValue(points.map { "\($0) points" } ?? "No score entered")
        .accessibilityHint("Double tap to enter a score")
    }
}

#Preview {
    ScoreCell(points: 7, playerName: "Ada", action: {})
}
