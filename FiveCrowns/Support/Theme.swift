import SwiftUI

/// Semantic colours over the asset catalog. Xcode generates a symbol per
/// colorset, so these are checked at compile time rather than by string.
enum Theme {
    static let background = Color(.background)
    static let backgroundMiddle = Color(.backgroundMiddle)
    static let backgroundDark = Color(.backgroundDark)
    static let row = Color(.rowColour)
    static let headerRow = Color(.headerRowBackground)
    static let button = Color(.buttonColour)

    static let primaryText = Color(.primaryText)
    static let secondaryText = Color(.secondaryText)
    static let onHeader = Color(.onHeader)

    static let backgroundGradient = Gradient(colors: [backgroundDark, backgroundMiddle, background])
}
