import SwiftUI
import UIKit

enum AppFont {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .ultraLight:  fontName = "Inter-Thin"
        case .thin:       fontName = "Inter-Thin"
        case .light:      fontName = "Inter-Light"
        case .regular:    fontName = "Inter-Regular"
        case .medium:     fontName = "Inter-Medium"
        case .semibold:   fontName = "Inter-Semibold"
        case .bold:       fontName = "Inter-Bold"
        case .heavy:      fontName = "Inter-Bold"
        case .black:      fontName = "Inter-Black"
        default:          fontName = "Inter-Regular"
        }
        return .custom(fontName, size: size)
    }
}

enum AppFontStyle: CaseIterable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
    
    var font: Font {
        let size: CGFloat
        let weight: Font.Weight
        
        switch self {
        case .largeTitle:  size = 34; weight = .bold
        case .title:       size = 28; weight = .bold
        case .title2:      size = 22; weight = .bold
        case .title3:      size = 20; weight = .semibold
        case .headline:    size = 17; weight = .semibold
        case .body:        size = 17; weight = .regular
        case .callout:     size = 16; weight = .regular
        case .subheadline: size = 15; weight = .regular
        case .footnote:    size = 13; weight = .regular
        case .caption:     size = 12; weight = .regular
        case .caption2:    size = 11; weight = .regular
        }
        
        return AppFont.inter(size: size, weight: weight)
    }
    
    var uiFont: UIFont {
        let size: CGFloat
        let weight: UIFont.Weight
        
        switch self {
        case .largeTitle:  size = 34; weight = .bold
        case .title:       size = 28; weight = .bold
        case .title2:      size = 22; weight = .bold
        case .title3:      size = 20; weight = .semibold
        case .headline:    size = 17; weight = .semibold
        case .body:        size = 17; weight = .regular
        case .callout:     size = 16; weight = .regular
        case .subheadline: size = 15; weight = .regular
        case .footnote:    size = 13; weight = .regular
        case .caption:     size = 12; weight = .regular
        case .caption2:    size = 11; weight = .regular
        }
        
        let fontName = "Inter-\(weight == .regular ? "Regular" : weight == .bold ? "Bold" : weight == .semibold ? "SemiBold" : weight == .medium ? "Medium" : weight == .light ? "Light" : weight == .thin ? "Thin" : weight == .black ? "Black" : "Regular")"
        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

extension UIFont {
    static func inter(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let fontName: String
        switch weight {
        case .ultraLight, .thin: fontName = "Inter-Thin"
        case .light: fontName = "Inter-Light"
        case .regular: fontName = "Inter-Regular"
        case .medium: fontName = "Inter-Medium"
        case .semibold: fontName = "Inter-SemiBold"
        case .bold, .heavy: fontName = "Inter-Bold"
        case .black: fontName = "Inter-Black"
        default: fontName = "Inter-Regular"
        }
        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

extension View {
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(style.font)
    }
}
