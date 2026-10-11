import SwiftUI

/// App-wide design tokens. All colors, spacing, and radii should be
/// sourced from this file to maintain consistency.
enum Theme {

    // MARK: - Brand Colors

    static let primary      = Color("Primary")          // Indigo #5B5BF0
    static let bestGreen    = Color("BestGreen")        // Keep badge
    static let deleteRed    = Color("DeleteRed")        // Delete / warning
    static let photosColor  = Color("PhotosIndigo")
    static let screensColor = Color("ScreensCyan")
    static let videosColor  = Color("VideosAmber")
    static let contactsColor = Color("ContactsPink")

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
    static let ringStroke: CGFloat = 3
}
