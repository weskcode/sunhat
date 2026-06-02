import SwiftUI
import UIKit

enum AppFont {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
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
        switch self {
        case .largeTitle:  .largeTitle.weight(.bold)
        case .title:       .title.weight(.bold)
        case .title2:      .title2.weight(.bold)
        case .title3:      .title3.weight(.semibold)
        case .headline:    .headline
        case .body:        .body
        case .callout:     .callout
        case .subheadline: .subheadline
        case .footnote:    .footnote
        case .caption:     .caption
        case .caption2:    .caption2
        }
    }
    
    var uiFont: UIFont {
        switch self {
        case .largeTitle:  UIFont.preferredFont(forTextStyle: .largeTitle).weighted(.bold, textStyle: .largeTitle)
        case .title:       UIFont.preferredFont(forTextStyle: .title1).weighted(.bold, textStyle: .title1)
        case .title2:      UIFont.preferredFont(forTextStyle: .title2).weighted(.bold, textStyle: .title2)
        case .title3:      UIFont.preferredFont(forTextStyle: .title3).weighted(.semibold, textStyle: .title3)
        case .headline:    .preferredFont(forTextStyle: .headline)
        case .body:        .preferredFont(forTextStyle: .body)
        case .callout:     .preferredFont(forTextStyle: .callout)
        case .subheadline: .preferredFont(forTextStyle: .subheadline)
        case .footnote:    .preferredFont(forTextStyle: .footnote)
        case .caption:     .preferredFont(forTextStyle: .caption1)
        case .caption2:    .preferredFont(forTextStyle: .caption2)
        }
    }
}

extension UIFont {
    static func inter(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    fileprivate func weighted(_ weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return metrics.scaledFont(for: UIFont(descriptor: descriptor, size: pointSize))
    }
}

extension View {
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(style.font)
    }
}
