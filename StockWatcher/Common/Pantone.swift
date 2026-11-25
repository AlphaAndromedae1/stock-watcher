import SwiftUI

/// Widget accent palette built from named PANTONE colors (sRGB approximations
/// of the published swatches). Centralizing them keeps the widget's look
/// deliberate and consistent instead of scattered ad-hoc RGB values.
enum Pantone {
    // Core semantics
    static let emerald      = rgb(0,   148, 115)   // 17-5641  Emerald        — gains / up
    static let greenery     = rgb(136, 176,  75)   // 15-0343  Greenery
    static let livingCoral  = rgb(255, 111,  97)   // 16-1546  Living Coral   — losses / down
    static let flameScarlet = rgb(205,  33,  42)   // 18-1662  Flame Scarlet  — strong down
    static let classicBlue  = rgb(15,   76, 129)   // 19-4052  Classic Blue   — brand / accent
    static let illuminating = rgb(245, 223,  77)   // 13-0647  Illuminating   — caution (yellow)
    static let ultimateGray = rgb(147, 149, 151)   // 17-5104  Ultimate Gray  — neutral
    static let marigold     = rgb(253, 172,  83)   // 14-1050  Marigold       — gold
    static let tangerine    = rgb(248, 143,  88)   // 15-1247  Tangerine
    static let aquaSky      = rgb(123, 196, 207)   // 14-4811  Aqua Sky
    static let vivaMagenta  = rgb(190,  52,  85)   // 18-1750  Viva Magenta

    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}
