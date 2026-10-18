import SwiftUI
import UIKit

enum AppTheme {
    static let ink = Color.theme(
        light: UIColor(red: 0.11, green: 0.16, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
    )
    static let muted = Color.theme(
        light: UIColor(red: 0.35, green: 0.41, blue: 0.45, alpha: 1),
        dark: UIColor(red: 0.70, green: 0.74, blue: 0.76, alpha: 1)
    )
    static let paper = Color.theme(
        light: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    )
    static let card = Color.theme(
        light: .white,
        dark: UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1)
    )
    static let navy = Color.theme(
        light: UIColor(red: 0.04, green: 0.24, blue: 0.36, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.82, blue: 0.92, alpha: 1)
    )
    static let navySoft = Color.theme(
        light: UIColor(red: 0.10, green: 0.35, blue: 0.48, alpha: 1),
        dark: UIColor(red: 0.48, green: 0.70, blue: 0.82, alpha: 1)
    )
    /// Solid fill for buttons with white labels; does not flip in Dark Mode.
    static let navyButton = Color(red: 0.04, green: 0.24, blue: 0.36)
    static let navyButtonPressed = Color(red: 0.10, green: 0.35, blue: 0.48)
    static let gold = Color.theme(
        light: UIColor(red: 0.78, green: 0.58, blue: 0.22, alpha: 1),
        dark: UIColor(red: 0.90, green: 0.74, blue: 0.38, alpha: 1)
    )
    static let goldSoft = Color.theme(
        light: UIColor(red: 0.93, green: 0.82, blue: 0.55, alpha: 1),
        dark: UIColor(red: 0.42, green: 0.34, blue: 0.16, alpha: 1)
    )
    static let forest = Color.theme(
        light: UIColor(red: 0.18, green: 0.42, blue: 0.31, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.78, blue: 0.58, alpha: 1)
    )
    static let rust = Color.theme(
        light: UIColor(red: 0.61, green: 0.18, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.48, blue: 0.45, alpha: 1)
    )
    static let sky = Color.theme(
        light: UIColor(red: 0.85, green: 0.91, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.24, blue: 0.28, alpha: 1)
    )

    static let radius: CGFloat = 18

    static func configureInputAppearance() {
        let text = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
                : UIColor(red: 0.11, green: 0.16, blue: 0.20, alpha: 1)
        }
        let caret = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.62, green: 0.82, blue: 0.92, alpha: 1)
                : UIColor(red: 0.10, green: 0.35, blue: 0.48, alpha: 1)
        }
        UITextField.appearance().textColor = text
        UITextField.appearance().tintColor = caret
        UITextField.appearance().backgroundColor = .clear
        UITextView.appearance().textColor = text
        UITextView.appearance().tintColor = caret
        UITextView.appearance().backgroundColor = .clear
    }
}

private extension Color {
    static func theme(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    func paperBackground() -> some View {
        background(AppTheme.paper.ignoresSafeArea())
    }
}
