import SwiftUI

struct RoundHeader: View {
    let round: Round

    var body: some View {
        HStack(spacing: 0) {
            logo
            Spacer()
            Text("\(round.cardCount) Card Round")
                .foregroundStyle(.black.opacity(0.7))
                .fontWeight(.bold)
                .font(.title2)
                .padding()
            Spacer()
            logo
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
    }

    private var logo: some View {
        Image("ScorecardLogo", bundle: .main)
            .resizable()
            .frame(width: 66, height: 66)
            .padding(.horizontal, 8)
    }
}

#Preview {
    RoundHeader(round: .three)
}
