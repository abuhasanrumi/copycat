import SwiftUI
import AppKit

struct Pinboard: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colorIndex: Int

    static let palette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen,
                                     .systemTeal, .systemBlue, .systemPurple, .systemPink]

    var color: Color { Color(nsColor: Self.palette[colorIndex % Self.palette.count]) }
}
