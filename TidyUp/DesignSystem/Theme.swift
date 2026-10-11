import SwiftUI

/// App-wide design tokens. All colors, spacing, and radii should be
/// sourced from this file to maintain consistency.
enum Theme {

    // MARK: - Brand Colors

    static let primary       = Color(red: 91 / 255.0, green: 91 / 255.0, blue: 240 / 255.0)    // Indigo #5B5BF0
    static let bestGreen     = Color(red: 22 / 255.0, green: 163 / 255.0, blue: 74 / 255.0)   // Keep badge #16A34A
    static let deleteRed     = Color(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0)   // Delete / warning #EF4444
    static let photosColor   = Color(red: 99 / 255.0, green: 102 / 255.0, blue: 241 / 255.0)  // PhotosIndigo #6366F1
    static let screensColor  = Color(red: 6 / 255.0, green: 182 / 255.0, blue: 212 / 255.0)   // ScreensCyan #06B6D4
    static let videosColor   = Color(red: 245 / 255.0, green: 158 / 255.0, blue: 11 / 255.0)  // VideosAmber #F59E0B
    static let contactsColor = Color(red: 236 / 255.0, green: 72 / 255.0, blue: 153 / 255.0)  // ContactsPink #EC4899

    // MARK: - Spacing Grid (base-4/8)

    static let spacing4:  CGFloat = 4
    static let spacing8:  CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing48: CGFloat = 48

    // MARK: - Corner Radii

    static let radiusCard:    CGFloat = 10
    static let radiusSheet:   CGFloat = 16
    static let radiusHero:    CGFloat = 24

    // MARK: - Storage Ring

    static let ringSize:   CGFloat = 200
    static let ringStroke: CGFloat = 16
}
