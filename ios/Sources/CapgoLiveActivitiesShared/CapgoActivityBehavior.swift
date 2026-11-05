import Foundation
import SwiftUI

public struct CapgoActivityBehavior {
    public var widgetURL: URL?
    public var backgroundTint: Color?
    public var systemActionForegroundColor: Color?
    public var keyLineTint: Color?

    public init(
        widgetURL: URL? = nil,
        backgroundTint: Color? = nil,
        systemActionForegroundColor: Color? = nil,
        keyLineTint: Color? = nil
    ) {
        self.widgetURL = widgetURL
        self.backgroundTint = backgroundTint
        self.systemActionForegroundColor = systemActionForegroundColor
        self.keyLineTint = keyLineTint
    }

    public static func parse(json: String?) -> CapgoActivityBehavior {
        guard let json,
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CapgoActivityBehavior()
        }

        var widgetURL: URL?
        if let urlString = object["widgetUrl"] as? String {
            widgetURL = URL(string: urlString)
        }

        return CapgoActivityBehavior(
            widgetURL: widgetURL,
            backgroundTint: CapgoColorParser.color(from: object["backgroundTint"] as? String),
            systemActionForegroundColor: CapgoColorParser.color(from: object["systemActionForegroundColor"] as? String),
            keyLineTint: CapgoColorParser.color(from: object["keyLineTint"] as? String)
        )
    }
}
