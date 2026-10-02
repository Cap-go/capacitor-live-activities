import ActivityKit
import CapgoLiveActivitiesShared
import SwiftUI
import WidgetKit

struct CapgoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CapgoLiveActivityAttributes.self) { context in
            let groupId = appGroupIdentifier()
            CapgoLayoutRenderer.lockScreenView(
                layoutJSON: context.attributes.layoutJSON,
                data: context.state.data,
                appGroupId: groupId
            )
            .padding(12)
            .activityBackgroundTint(Color.black.opacity(0.2))
        } dynamicIsland: { context in
            let groupId = appGroupIdentifier()
            let island = parseIsland(context.attributes.dynamicIslandLayoutJSON)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CapgoLayoutRenderer.islandView(
                        elementJSON: island?.leading,
                        data: context.state.data,
                        appGroupId: groupId
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CapgoLayoutRenderer.islandView(
                        elementJSON: island?.trailing,
                        data: context.state.data,
                        appGroupId: groupId
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    CapgoLayoutRenderer.islandView(
                        elementJSON: island?.center,
                        data: context.state.data,
                        appGroupId: groupId
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CapgoLayoutRenderer.islandView(
                        elementJSON: island?.bottom,
                        data: context.state.data,
                        appGroupId: groupId
                    )
                }
            } compactLeading: {
                CapgoLayoutRenderer.islandView(
                    elementJSON: island?.compactLeading,
                    data: context.state.data,
                    appGroupId: groupId
                )
            } compactTrailing: {
                CapgoLayoutRenderer.islandView(
                    elementJSON: island?.compactTrailing,
                    data: context.state.data,
                    appGroupId: groupId
                )
            } minimal: {
                CapgoLayoutRenderer.islandView(
                    elementJSON: island?.minimal,
                    data: context.state.data,
                    appGroupId: groupId
                )
            }
        }
    }

    private func appGroupIdentifier() -> String? {
        "group.app.capgo.live.activities.liveactivities"
    }

    private func parseIsland(_ json: String) -> IslandRegions? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let expanded = object["expanded"] as? [String: Any]
        return IslandRegions(
            leading: elementJSON(expanded?["leading"]),
            trailing: elementJSON(expanded?["trailing"]),
            center: elementJSON(expanded?["center"]),
            bottom: elementJSON(expanded?["bottom"]),
            compactLeading: elementJSON(object["compactLeading"]),
            compactTrailing: elementJSON(object["compactTrailing"]),
            minimal: elementJSON(object["minimal"])
        )
    }

    private func elementJSON(_ value: Any?) -> String? {
        guard let value else { return nil }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

private struct IslandRegions {
    let leading: String?
    let trailing: String?
    let center: String?
    let bottom: String?
    let compactLeading: String?
    let compactTrailing: String?
    let minimal: String?
}
