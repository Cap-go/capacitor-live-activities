import ActivityKit
import Foundation

public struct CapgoLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var data: [String: CapgoJSONValue]

        public init(data: [String: CapgoJSONValue]) {
            self.data = data
        }
    }

    public var activityId: String
    public var layoutJSON: String
    public var dynamicIslandLayoutJSON: String
    public var behaviorJSON: String?

    public init(
        activityId: String,
        layoutJSON: String,
        dynamicIslandLayoutJSON: String,
        behaviorJSON: String?
    ) {
        self.activityId = activityId
        self.layoutJSON = layoutJSON
        self.dynamicIslandLayoutJSON = dynamicIslandLayoutJSON
        self.behaviorJSON = behaviorJSON
    }
}
