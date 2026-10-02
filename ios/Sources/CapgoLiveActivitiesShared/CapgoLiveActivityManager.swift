import ActivityKit
import Foundation

public final class CapgoLiveActivityManager {
    public static let shared = CapgoLiveActivityManager()

    private struct StoredActivity {
        var config: [String: Any]
        var pushToken: String?
        var activity: Any?
    }

    private var activities: [String: StoredActivity] = [:]
    private let lock = NSLock()

    private init() {}

    public func start(
        activityId: String,
        layout: [String: Any],
        dynamicIslandLayout: [String: Any],
        behavior: [String: Any]?,
        data: [String: Any],
        staleDate: Double?,
        relevanceScore: Double?,
        appGroupId: String?
    ) throws {
        guard #available(iOS 16.1, *) else {
            throw CapgoLiveActivityError.unsupported
        }

        let layoutJSON = jsonString(layout)
        let islandJSON = jsonString(dynamicIslandLayout)
        let behaviorJSON = behavior == nil ? nil : jsonString(behavior!)

        let contentData = capgoValues(from: data)
        let attributes = CapgoLiveActivityAttributes(
            activityId: activityId,
            layoutJSON: layoutJSON,
            dynamicIslandLayoutJSON: islandJSON,
            behaviorJSON: behaviorJSON
        )
        let contentState = CapgoLiveActivityAttributes.ContentState(data: contentData)

        let stale: Date? = staleDate.map { Date(timeIntervalSince1970: $0 / 1000) }
        let relevance = relevanceScore.map { min(max($0, 0), 100) }

        let activity: Activity<CapgoLiveActivityAttributes>
        if #available(iOS 16.2, *) {
            let content = ActivityContent(
                state: contentState,
                staleDate: stale,
                relevanceScore: relevance
            )
            do {
                activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
            } catch {
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        } else {
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: .token
                )
            } catch {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
        }

        let config: [String: Any] = [
            "layout": layout,
            "dynamicIslandLayout": dynamicIslandLayout,
            "behavior": behavior ?? [:],
            "data": data,
            "staleDate": staleDate as Any,
            "relevanceScore": relevanceScore as Any,
            "startDate": Date().timeIntervalSince1970 * 1000,
            "state": "active",
            "appGroupId": appGroupId as Any
        ]

        lock.lock()
        activities[activityId] = StoredActivity(config: config, pushToken: nil, activity: activity)
        lock.unlock()

        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                lock.lock()
                if var stored = activities[activityId] {
                    stored.pushToken = token
                    activities[activityId] = stored
                }
                lock.unlock()
            }
        }
    }

    public func update(
        activityId: String,
        data: [String: Any],
        staleDate: Double?,
        relevanceScore: Double?
    ) throws {
        guard #available(iOS 16.1, *) else {
            throw CapgoLiveActivityError.unsupported
        }

        lock.lock()
        guard var stored = activities[activityId],
              let activity = stored.activity as? Activity<CapgoLiveActivityAttributes> else {
            lock.unlock()
            throw CapgoLiveActivityError.notFound
        }
        stored.config["data"] = data
        if let staleDate { stored.config["staleDate"] = staleDate }
        if let relevanceScore { stored.config["relevanceScore"] = relevanceScore }
        activities[activityId] = stored
        lock.unlock()

        let contentData = capgoValues(from: data)
        let stale: Date? = staleDate.map { Date(timeIntervalSince1970: $0 / 1000) }
        let relevance = relevanceScore.map { min(max($0, 0), 100) }

        let nextState = CapgoLiveActivityAttributes.ContentState(data: contentData)
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(
                    state: nextState,
                    staleDate: stale,
                    relevanceScore: relevance
                )
                await activity.update(content)
            } else {
                await activity.update(using: nextState)
            }
        }
    }

    public func end(
        activityId: String,
        data: [String: Any]?,
        dismissalPolicy: String?,
        dismissAfter: Double?
    ) throws {
        guard #available(iOS 16.1, *) else {
            throw CapgoLiveActivityError.unsupported
        }

        lock.lock()
        guard let stored = activities[activityId],
              let activity = stored.activity as? Activity<CapgoLiveActivityAttributes> else {
            lock.unlock()
            throw CapgoLiveActivityError.notFound
        }
        let fallbackData = stored.config["data"] as? [String: Any] ?? [:]
        lock.unlock()

        let finalData = capgoValues(from: data ?? fallbackData)
        let policy = dismissalPolicyFrom(dismissalPolicy, dismissAfter: dismissAfter)

        let finalState = CapgoLiveActivityAttributes.ContentState(data: finalData)
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: policy)
            } else {
                await activity.end(using: finalState, dismissalPolicy: policy)
            }
        }

        lock.lock()
        if var updated = activities[activityId] {
            updated.config["state"] = "ended"
            if let data { updated.config["data"] = data }
            updated.activity = nil
            activities[activityId] = updated
        }
        lock.unlock()
    }

    public func allActivities() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return activities.map { activityId, stored in
            [
                "activityId": activityId,
                "state": stored.config["state"] as? String ?? "active",
                "startDate": stored.config["startDate"] ?? 0,
                "data": stored.config["data"] ?? [:],
                "pushToken": stored.pushToken as Any
            ]
        }
    }

    private func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func capgoValues(from data: [String: Any]) -> [String: CapgoJSONValue] {
        var result: [String: CapgoJSONValue] = [:]
        for (key, value) in data {
            result[key] = capgoValue(from: value)
        }
        return result
    }

    private func capgoValue(from value: Any) -> CapgoJSONValue {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Int:
            return .int(value)
        case let value as Double:
            return .double(value)
        case let value as Bool:
            return .bool(value)
        case let value as [String: Any]:
            var object: [String: CapgoJSONValue] = [:]
            for (key, nested) in value {
                object[key] = capgoValue(from: nested)
            }
            return .object(object)
        case let value as [Any]:
            return .array(value.map { capgoValue(from: $0) })
        default:
            return .null
        }
    }

    @available(iOS 16.1, *)
    private func dismissalPolicyFrom(_ policy: String?, dismissAfter: Double?) -> ActivityUIDismissalPolicy {
        switch policy {
        case "immediate":
            return .immediate
        case "after":
            if let dismissAfter {
                let date = Date(timeIntervalSince1970: dismissAfter / 1000)
                return .after(date)
            }
            return .default
        default:
            return .default
        }
    }
}

public enum CapgoLiveActivityError: Error {
    case unsupported
    case notFound
}
