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
                if let tint {
                    return AnyView(scaled(Image(systemName: value)).foregroundColor(tint))
                }
                return scaled(Image(systemName: value))
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
                // Live Activities cannot load remote images. Download the image in the app
                // and render it with source "saved" instead.
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
        let now = Date()
        let reached = date <= now

        let timerText: Text = {
            if CapgoTimerLogic.usesPausedZeroWhenReached(pausesOnReach: pausesOnReach, target: date, now: now) {
                return Text(timerInterval: date...date.addingTimeInterval(1), pauseTime: date, countsDown: true)
            }
            switch style {
            case "relative":
                return Text(date, style: .relative)
            case "offset":
                if reached {
                    return Text(date, format: .dateTime.hour().minute().second())
                }
                return Text(timerInterval: now...date, countsDown: true)
            default:
                if pausesOnReach {
                    return Text(timerInterval: now...date, pauseTime: date, countsDown: true)
                }
                return Text(date, style: .timer)
            }
        }()

        let view = timerText
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(color)
            .monospacedDigit()
        applyProperties(view, props: element["properties"] as? [String: Any])
    }

    @ViewBuilder
    private static func gaugeView(element: [String: Any], data: [String: CapgoJSONValue]) -> some View {
        let value = min(max(numericValue(element["value"], data: data) ?? 0, 0), 1)
        let tint = colorFrom(element["tint"] as? String) ?? .blue
        let label = element["label"] as? String
        let current = element["currentValueLabel"] as? String
        let minimum = element["minimumValueLabel"] as? String
        let maximum = element["maximumValueLabel"] as? String
        let props = element["properties"] as? [String: Any]
        let styleName = element["style"] as? String

        switch styleName {
        case "linearCapacity":
            applyProperties(
                Gauge(value: value, in: 0 ... 1) {
                    if let label { Text(label) }
                } currentValueLabel: {
                    if let current { Text(current) }
                } minimumValueLabel: {
                    if let minimum { Text(minimum) }
                } maximumValueLabel: {
                    if let maximum { Text(maximum) }
                }
                .gaugeStyle(.linearCapacity)
                .tint(tint),
                props: props
            )
        case "accessoryCircularCapacity":
            applyProperties(
                Gauge(value: value, in: 0 ... 1) {
                    if let label { Text(label) }
                } currentValueLabel: {
                    if let current { Text(current) }
                } minimumValueLabel: {
                    if let minimum { Text(minimum) }
                } maximumValueLabel: {
                    if let maximum { Text(maximum) }
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(tint),
                props: props
            )
        case "automatic":
            applyProperties(
                Gauge(value: value, in: 0 ... 1) {
                    if let label { Text(label) }
                } currentValueLabel: {
                    if let current { Text(current) }
                } minimumValueLabel: {
                    if let minimum { Text(minimum) }
                } maximumValueLabel: {
                    if let maximum { Text(maximum) }
                }
                .gaugeStyle(.automatic)
                .tint(tint),
                props: props
            )
        default:
            applyProperties(
                Gauge(value: value, in: 0 ... 1) {
                    if let label { Text(label) }
                } currentValueLabel: {
                    if let current { Text(current) }
                } minimumValueLabel: {
                    if let minimum { Text(minimum) }
                } maximumValueLabel: {
                    if let maximum { Text(maximum) }
                }
                .gaugeStyle(.accessoryCircular)
                .tint(tint),
                props: props
            )
        }
    }

    private static func applyProperties<V: View>(_ view: V, props: [String: Any]?) -> some View {
        guard let props else { return AnyView(view) }
        var result = AnyView(view)
        if let padding = props["padding"] as? Double {
            result = AnyView(result.padding(padding))
        } else if let padding = props["padding"] as? [String: Any] {
            result = AnyView(result.padding(EdgeInsets(
                top: CGFloat(padding["top"] as? Double ?? 0),
                leading: CGFloat(padding["leading"] as? Double ?? 0),
                bottom: CGFloat(padding["bottom"] as? Double ?? 0),
                trailing: CGFloat(padding["trailing"] as? Double ?? 0)
            )))
        }
        if props["width"] as? String == "infinity" {
            result = AnyView(result.frame(maxWidth: .infinity))
        } else if let width = props["width"] as? Double {
            result = AnyView(result.frame(width: width))
        }
        if let height = props["height"] as? Double {
            result = AnyView(result.frame(height: height))
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
        CapgoColorParser.color(from: raw)
    }

    private static func fontDesign(_ raw: String?) -> Font.Design {
        switch raw {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
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
