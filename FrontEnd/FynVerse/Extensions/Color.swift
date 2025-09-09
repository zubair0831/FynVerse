//
//  Color.swift
//  FynVerse
//
//  Created by zubair ahmed on 15/07/25.
//


import SwiftUI


struct ColorTheme {
    // Brand & Accent Colors
    let accent = Color("AccentColor") // Brand-specific accent color; keep asset name
    let green = Color("GreeenColor")   // Use correct spelling and standard color asset
    let red = Color("ReedColor")       // Same as above
    let secondary = Color("SecondaryTextColor") // For secondary text elements

    // Background gradients with subtle, cool tones for a formal trading app look
    /*
    let background =                 LinearGradient(
        colors: [ Color(red: 127/255, green: 255/255, blue: 212/255), .teal.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )*/
    let background =   LinearGradient(
            // A gentle gradient from a light, airy teal to a muted, deep green
            colors: [Color(red: 200/255, green: 230/255, blue: 220/255), Color(red: 100/255, green: 170/255, blue: 150/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    let cardBackground = Color.gray.opacity(0.2)
}

extension Color{
    static let theme = ColorTheme()
}
