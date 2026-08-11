import SwiftUI

/// Non-blocking notice shown when the most recent background save failed.
struct SaveFailedBanner: View {
    var body: some View {
        Label("Couldn't save this game", systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.85))
    }
}

#Preview {
    SaveFailedBanner()
}
