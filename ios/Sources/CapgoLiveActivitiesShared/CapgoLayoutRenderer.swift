import SwiftUI
import UIKit
import WidgetKit

public enum CapgoLayoutRenderer {
    public static func lockScreenView(
        layoutJSON: String,
        data: [String: CapgoJSONValue],
        appGroupId: String?
    ) -> AnyView {
        guard let layout = parseLayout(layoutJSON) else {
            return AnyView(Text("Live Activity"))
        }
        return AnyView(render(element: layout, data: data, appGroupId: appGroupId))
    }

    public static func islandView(
        elementJSON: String?,
        data: [String: CapgoJSONValue],
        appGroupId: String?
    ) -> AnyView {
        guard let json = elementJSON, let layout = parseLayout(json) else {
            return AnyView(EmptyView())
        }
        return AnyView(render(element: layout, data: data, appGroupId: appGroupId))
    }

    private static func parseLayout(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    @ViewBuilder
    private static func render(
        element: [String: Any],
        data: [String: CapgoJSONValue],
        appGroupId: String?
    ) -> some View {
        let type = element["type"] as? String ?? "text"
        switch type {
        case "container":
            containerView(element: element, data: data, appGroupId: appGroupId)
        case "text":
            textView(element: element, data: data)
        case "image":
            imageView(element: element, data: data, appGroupId: appGroupId)
        case "progress":
            progressView(element: element, data: data)
        case "timer":
            timerView(element: element, data: data)
        case "spacer":
            Spacer(minLength: CGFloat(element["minLength"] as? Double ?? 0))
        case "gauge":
            gaugeView(element: element, data: data)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private static func containerView(
        element: [String: Any],
        data: [String: CapgoJSONValue],
        appGroupId: String?
    ) -> some View {
        let direction = element["direction"] as? String ?? "vertical"
        let spacing = CGFloat(element["spacing"] as? Double ?? 8)
        let children = element["children"] as? [[String: Any]] ?? []
        let props = element["properties"] as? [String: Any]

        let content: AnyView = {
            switch direction {
            case "horizontal":
                return AnyView(
                    HStack(alignment: verticalAlignment(element["alignment"] as? String), spacing: spacing) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            render(element: child, data: data, appGroupId: appGroupId)
                        }
                    }
                )
            case "zstack":
                return AnyView(
                    ZStack {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            render(element: child, data: data, appGroupId: appGroupId)
                        }
                    }
                )
            default:
                return AnyView(
                    VStack(alignment: horizontalAlignment(element["alignment"] as? String), spacing: spacing) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            render(element: child, data: data, appGroupId: appGroupId)
                        }
                    }
                )
            }
        }()

        applyProperties(content, props: props)
    }

    private static func textView(element: [String: Any], data: [String: CapgoJSONValue]) -> some View {
        let template = element["content"] as? String ?? ""
        let text = interpolate(template, data: data)
        let fontSize = CGFloat(element["fontSize"] as? Double ?? 14)
        let color = colorFrom(element["color"] as? String) ?? .primary
        let weight = fontWeight(element["fontWeight"] as? String)
        let design = fontDesign(element["fontDesign"] as? String)
        let lineLimit = element["lineLimit"] as? Int

        let view = Text(text)
            .font(.system(size: fontSize, weight: weight, design: design))
            .foregroundColor(color)
            .lineLimit(lineLimit)
            .multilineTextAlignment(textAlignment(element["alignment"] as? String))
        return applyProperties(view, props: element["properties"] as? [String: Any])
    }

    @ViewBuilder
    private static func imageView(
        element: [String: Any],
        data: [String: CapgoJSONValue],
        appGroupId: String?
    ) -> some View {
        let source = element["source"] as? String ?? "sfSymbol"
        let value = element["value"] as? String ?? ""
        let width = CGFloat(element["width"] as? Double ?? 24)
        let height = CGFloat(element["height"] as? Double ?? 24)
        let tint = colorFrom(element["tintColor"] as? String)

        let contentMode = element["contentMode"] as? String ?? "fit"
        let scaled: (Image) -> AnyView = { image in
            let resized = image.resizable().scaledToFit()
            if contentMode == "fill" {
                return AnyView(resized.scaledToFill().frame(width: width, height: height).clipped())
            }
            return AnyView(resized.frame(width: width, height: height))
        }

        let imageContent: AnyView = {
            switch source {
            case "sfSymbol":
                let symbol = tint.map { Image(systemName: value).foregroundColor($0) } ?? Image(systemName: value)
                return scaled(symbol)
            case "saved":
                if value.contains("/") || value.contains("..") {
                    return AnyView(Image(systemName: "photo").frame(width: width, height: height))
                }
                if let appGroupId,
                   let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
                    .appendingPathComponent("LiveActivityImages/\(value).jpg"),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    return scaled(Image(uiImage: uiImage))
                }
                return AnyView(Image(systemName: "photo").frame(width: width, height: height))
            case "url":
                if let url = URL(string: value) {
                    return AnyView(
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                scaled(image)
                            default:
                                Image(systemName: "photo").frame(width: width, height: height)
                            }
                        }
                    )
                }
                return AnyView(Image(systemName: "photo").frame(width: width, height: height))
            case "asset":
                return scaled(Image(value))
            case "base64":
                if let data = Data(base64Encoded: value), let uiImage = UIImage(data: data) {
                    return scaled(Image(uiImage: uiImage))
                }
                return AnyView(Image(systemName: "photo").frame(width: width, height: height))
            default:
                return AnyView(Image(systemName: "questionmark").frame(width: width, height: height))
            }
        }()

        return applyProperties(imageContent, props: element["properties"] as? [String: Any])
    }

    private static func progressView(element: [String: Any], data: [String: CapgoJSONValue]) -> some View {
        let value = numericValue(element["value"], data: data) ?? 0
        let total = numericValue(element["total"], data: data) ?? 1
        let progress = total > 0 ? min(max(value / total, 0), 1) : 0
        let tint = colorFrom(element["tint"] as? String) ?? .green
        let view = ProgressView(value: progress).tint(tint)
        return applyProperties(view, props: element["properties"] as? [String: Any])
    }

    @ViewBuilder
    private static func timerView(element: [String: Any], data: [String: CapgoJSONValue]) -> some View {
        let timestamp = numericValue(element["targetDate"], data: data) ?? Date().timeIntervalSince1970 * 1000
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let fontSize = CGFloat(element["fontSize"] as? Double ?? 16)
        let color = colorFrom(element["color"] as? String) ?? .primary
        let weight = fontWeight(element["fontWeight"] as? String)
        let style = element["style"] as? String ?? "timer"
        let pausesOnReach = element["pausesOnReach"] as? Bool ?? false
        let reached = date <= Date()

        let timerText: Text = {
            if pausesOnReach && reached {
                return Text(date, format: .dateTime.hour().minute().second())
            }
            switch style {
            case "relative":
                return Text(date, style: .relative)
            case "offset":
                return Text(timerInterval: Date()...date, countsDown: true)
            default:
                return Text(date, style: .timer)
            }
        }()

        let view = timerText
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(color)
            .monospacedDigit()
        applyProperties(view, props: element["properties"] as? [String: Any])
    }

    private static func gaugeView(element: [String: Any], data: [String: CapgoJSONValue]) -> some View {
        let value = min(max(numericValue(element["value"], data: data) ?? 0, 0), 1)
        let tint = colorFrom(element["tint"] as? String) ?? .blue
        let label = element["label"] as? String
        let current = element["currentValueLabel"] as? String
        let minimum = element["minimumValueLabel"] as? String
        let maximum = element["maximumValueLabel"] as? String
        let style = gaugeStyle(element["style"] as? String)

        let gauge = Gauge(value: value, in: 0 ... 1) {
            if let label { Text(label) }
        } currentValueLabel: {
            if let current { Text(current) }
        } minimumValueLabel: {
            if let minimum { Text(minimum) }
        } maximumValueLabel: {
            if let maximum { Text(maximum) }
        }
        .gaugeStyle(style)
        .tint(tint)

        return applyProperties(gauge, props: element["properties"] as? [String: Any])
    }

    private static func applyProperties<V: View>(_ view: V, props: [String: Any]?) -> some View {
        guard let props else { return AnyView(view) }
        var result = AnyView(view)
        if let padding = props["padding"] as? Double {
            result = AnyView(result.padding(padding))
        }
        if let background = props["backgroundColor"] as? String, let color = colorFrom(background) {
            result = AnyView(result.background(color))
        }
        if let cornerRadius = props["cornerRadius"] as? Double {
            result = AnyView(result.cornerRadius(cornerRadius))
        }
        if let opacity = props["opacity"] as? Double {
            result = AnyView(result.opacity(opacity))
        }
        return result
    }

    private static func interpolate(_ template: String, data: [String: CapgoJSONValue]) -> String {
        var output = template
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                  let fullRange = Range(match.range, in: template) else { continue }
            let key = String(template[keyRange]).trimmingCharacters(in: .whitespaces)
            let replacement = data[key]?.stringValue ?? ""
            output.replaceSubrange(fullRange, with: replacement)
        }
        return output
    }

    private static func numericValue(_ raw: Any?, data: [String: CapgoJSONValue]) -> Double? {
        if let key = raw as? String, let value = data[key]?.doubleValue {
            return value
        }
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        return nil
    }

    private static func colorFrom(_ raw: String?) -> Color? {
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

    private static func fontDesign(_ raw: String?) -> Font.Design {
        switch raw {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }

    private static func gaugeStyle(_ raw: String?) -> GaugeStyle {
        switch raw {
        case "linearCapacity":
            return .linearCapacity
        case "accessoryCircularCapacity":
            return .accessoryCircularCapacity
        case "automatic":
            return .automatic
        default:
            return .accessoryCircular
        }
    }

    private static func fontWeight(_ raw: String?) -> Font.Weight {
        switch raw {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    private static func textAlignment(_ raw: String?) -> TextAlignment {
        switch raw {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private static func horizontalAlignment(_ raw: String?) -> HorizontalAlignment {
        switch raw {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private static func verticalAlignment(_ raw: String?) -> VerticalAlignment {
        switch raw {
        case "top": return .top
        case "bottom": return .bottom
        case "center": return .center
        default: return .center
        }
    }
}
