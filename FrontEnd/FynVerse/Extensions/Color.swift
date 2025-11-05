//
//  Color.swift
//  FynVerse
//
//  Created by Zubair Ahmed on 15/07/25.
//  Complete Redesign: Professional Dark Mode Trading Theme
//  Updated: Bold, Stylish & Premium Trading Experience
//

import SwiftUI
import UIKit

struct ColorTheme {
    // MARK: - Core Brand & Accent Colors (Bold & Premium)
    let accent = Color(red: 0/255, green: 230/255, blue: 118/255)       // Electric Emerald - Modern & Energetic
    let green = Color(red: 16/255, green: 185/255, blue: 129/255)      // Professional Jade Green - Confident Gains
    let red = Color(red: 239/255, green: 68/255, blue: 68/255)          // Bold Crimson - Clear Losses
    let blue = Color(red: 99/255, green: 102/255, blue: 241/255)        // Vivid Indigo - Premium Info
    let yellow = Color(red: 245/255, green: 158/255, blue: 11/255)      // Rich Amber - Attention & Warning
    
    var success: Color { green }
    var danger: Color { red }
    
    // MARK: - Adaptive Background (Deep Professional / Clean Premium)
    let background = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)  // Rich Obsidian Black
        default:
            return UIColor(red: 250/255, green: 251/255, blue: 252/255, alpha: 1.0)  // Sophisticated Off-White
        }
    })
    
    // MARK: - Adaptive Card & Surface
    let cardBackground = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 20/255, green: 20/255, blue: 28/255, alpha: 1.0)  // Premium Charcoal
        default:
            return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)  // Pure White Cards
        }
    })
    
    let cardShadow = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor.black.withAlphaComponent(0.4)  // Deep dimensional shadow
        default:
            return UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 0.08)  // Subtle premium shadow
        }
    })
    
    // MARK: - Adaptive Text Colors
    let primaryText = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)  // Pure White
        default:
            return UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)  // Rich Navy - Maximum Readability
        }
    })
    
    let secondary = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0)  // Refined Gray
        default:
            return UIColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1.0)  // Professional Slate
        }
    })
    
    let tertiaryText = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)  // Muted Gray
        default:
            return UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)  // Soft Mid-Gray
        }
    })
    
    // MARK: - Chart Colors (Bold & Clear)
    let chartLine = Color(red: 0/255, green: 230/255, blue: 118/255)    // Electric Emerald
    let chartNegativeLine = Color(red: 239/255, green: 68/255, blue: 68/255) // Bold Crimson
    
    let chartGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0/255, green: 230/255, blue: 118/255, alpha: 0.35)  // Vibrant Emerald Glow
                default:
                    return UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15)  // Subtle Professional Tint
                }
            }),
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 0.0)  // Transparent Fade to Background
                default:
                    return UIColor(red: 250/255, green: 251/255, blue: 252/255, alpha: 0.0)  // Transparent Fade
                }
            })
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Status & System Colors (Premium Palette)
    let warning = Color(red: 245/255, green: 158/255, blue: 11/255)      // Rich Amber
    let info = Color(red: 59/255, green: 130/255, blue: 246/255)         // Bright Sky Blue
    let purple = Color(red: 168/255, green: 85/255, blue: 247/255)       // Bold Purple
    let pink = Color(red: 236/255, green: 72/255, blue: 153/255)         // Vibrant Fuchsia
    
    // MARK: - Adaptive Buttons
    let buttonPrimary = Color(red: 0/255, green: 230/255, blue: 118/255) // Electric Emerald - Action Color
    
    let buttonSecondary = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 55/255, green: 65/255, blue: 81/255, alpha: 1.0)  // Refined Dark Gray
        default:
            return UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)  // Crisp Light Gray
        }
    })
    
    let buttonDisabled = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 55/255, green: 65/255, blue: 81/255, alpha: 0.5)
        default:
            return UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 0.6)
        }
    })
    
    // MARK: - Adaptive Dividers
    let divider = Color(uiColor: UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(red: 38/255, green: 38/255, blue: 48/255, alpha: 1.0)  // Subtle Dark Separator
        default:
            return UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0)  // Clean Light Border
        }
    })
    
    // MARK: - Adaptive Card Gradients (Premium Depth)
    let cardGradient1 = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)  // Jade Green
                default:
                    return UIColor(red: 236/255, green: 253/255, blue: 245/255, alpha: 1.0)  // Mint White
                }
            }),
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 5/255, green: 150/255, blue: 105/255, alpha: 1.0)  // Deep Emerald
                default:
                    return UIColor(red: 209/255, green: 250/255, blue: 229/255, alpha: 1.0)  // Soft Mint
                }
            })
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    let cardGradient2 = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1.0)  // Vivid Indigo
                default:
                    return UIColor(red: 238/255, green: 242/255, blue: 255/255, alpha: 1.0)  // Lavender White
                }
            }),
            Color(uiColor: UIColor { trait in
                switch trait.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)  // Bright Blue
                default:
                    return UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 1.0)  // Sky Blue Tint
                }
            })
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    static let theme = ColorTheme()
}
