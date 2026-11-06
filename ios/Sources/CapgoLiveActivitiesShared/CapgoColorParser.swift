import SwiftUI

public enum CapgoColorParser {
    public static func color(from raw: String?) -> Color? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("#") {
            let hex = String(raw.dropFirst())
            guard hex.count == 6 || hex.count == 8 else { return nil }
            var value: UInt64 = 0
            guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
            if hex.count == 6 {
                let r = Double((value & 0xFF0000) >> 16) / 255
                let g = Double((value & 0x00FF00) >> 8) / 255
                let b = Double(value & 0x0000FF) / 255
                return Color(red: r, green: g, blue: b)
            }
            let a = Double((value & 0xFF000000) >> 24) / 255
            let r = Double((value & 0x00FF0000) >> 16) / 255
            let g = Double((value & 0x0000FF00) >> 8) / 255
            let b = Double(value & 0x000000FF) / 255
            return Color(red: r, green: g, blue: b, opacity: a)
        }
        switch raw.lowercased() {
        case "primary": return .primary
        case "secondary": return .secondary
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "pink": return .pink
        case "purple": return .purple
        case "gray", "grey": return .gray
        default:
            if let uiColor = UIColor(named: raw) {
                return Color(uiColor)
            }
            return nil
        }
    }
}
