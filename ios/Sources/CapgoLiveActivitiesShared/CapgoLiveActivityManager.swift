import ActivityKit
import CoreFoundation
import Foundation

public final class CapgoLiveActivityManager {
    public static let shared = CapgoLiveActivityManager()

    private struct StoredActivity {
        var config: [String: Any]
        var pushToken: String?
        var activity: Any?
    }

    private var activities: [String: StoredActivity] = [:]
    private var observedPushTokenIds: Set<String> = []
    private let lock = NSLock()

    /// Persisted per-activity metadata (startDate, staleDate, relevanceScore) so records recovered
    /// from ActivityKit after an app restart keep the values reported at start or last update.
    private let metadataDefaultsKey = "CapgoLiveActivities.metadata"

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
        let relevance = normalizedRelevance(relevanceScore)

        let activity: Activity<CapgoLiveActivityAttributes>
        if #available(iOS 16.2, *) {
            let content: ActivityContent<CapgoLiveActivityAttributes.ContentState>
            if let relevance {
                content = ActivityContent(state: contentState, staleDate: stale, relevanceScore: relevance)
            } else {
                content = ActivityContent(state: contentState, staleDate: stale)
            }
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

        let startDate = Date().timeIntervalSince1970 * 1000
        var config: [String: Any] = [
            "layout": layout,
            "dynamicIslandLayout": dynamicIslandLayout,
            "behavior": behavior ?? [:],
            "data": data,
            "startDate": startDate,
            "state": "active",
            "appGroupId": appGroupId as Any
        ]
        if let staleDate { config["staleDate"] = staleDate }
        if let relevanceScore { config["relevanceScore"] = relevanceScore }

        lock.lock()
        activities[activityId] = StoredActivity(config: config, pushToken: nil, activity: activity)
        lock.unlock()
        saveMetadata(activityId: activityId, startDate: startDate, staleDate: staleDate, relevanceScore: relevanceScore)

        observePushTokens(for: activity, activityId: activityId)
    }

    @available(iOS 16.1, *)
    private func observePushTokens(for activity: Activity<CapgoLiveActivityAttributes>, activityId: String) {
        lock.lock()
        if observedPushTokenIds.contains(activityId) {
            lock.unlock()
            return
        }
        observedPushTokenIds.insert(activityId)
        if let current = activity.pushToken, var stored = activities[activityId], stored.pushToken == nil {
            stored.pushToken = hexString(current)
            activities[activityId] = stored
        }
        lock.unlock()

        Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                guard let self else { return }
                let token = self.hexString(tokenData)
                self.lock.lock()
                if var stored = self.activities[activityId] {
                    stored.pushToken = token
                    self.activities[activityId] = stored
                }
                self.lock.unlock()
            }
        }
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func loadAllMetadata() -> [String: [String: Double]] {
        UserDefaults.standard.dictionary(forKey: metadataDefaultsKey) as? [String: [String: Double]] ?? [:]
    }

    private func saveMetadata(activityId: String, startDate: Double? = nil, staleDate: Double?, relevanceScore: Double?) {
        var all = loadAllMetadata()
        var entry = all[activityId] ?? [:]
        if let startDate { entry["startDate"] = startDate }
        if let staleDate { entry["staleDate"] = staleDate }
        if let relevanceScore { entry["relevanceScore"] = relevanceScore }
        all[activityId] = entry
        UserDefaults.standard.set(all, forKey: metadataDefaultsKey)
    }

    private func removeMetadata(activityId: String) {
        var all = loadAllMetadata()
        guard all.removeValue(forKey: activityId) != nil else { return }
        UserDefaults.standard.set(all, forKey: metadataDefaultsKey)
    }

    public func update(
        activityId: String,
        data: [String: Any],
        staleDate: Double?,
        relevanceScore: Double?,
        alertConfig: [String: Any]?
    ) async throws {
        guard #available(iOS 16.1, *) else {
            throw CapgoLiveActivityError.unsupported
        }

        hydrateFromActivityKit()
        lock.lock()
        guard var stored = activities[activityId],
              let activity = stored.activity as? Activity<CapgoLiveActivityAttributes> else {
            lock.unlock()
            throw CapgoLiveActivityError.notFound
        }
        let effectiveStaleDate = staleDate ?? stored.config["staleDate"] as? Double
        let effectiveRelevance = relevanceScore ?? stored.config["relevanceScore"] as? Double
        stored.config["data"] = data
        if let staleDate { stored.config["staleDate"] = staleDate }
        if let relevanceScore { stored.config["relevanceScore"] = relevanceScore }
        activities[activityId] = stored
        lock.unlock()
        if staleDate != nil || relevanceScore != nil {
            saveMetadata(activityId: activityId, staleDate: staleDate, relevanceScore: relevanceScore)
        }

        let contentData = capgoValues(from: data)
        let stale: Date? = effectiveStaleDate.map { Date(timeIntervalSince1970: $0 / 1000) }
        let relevance = normalizedRelevance(effectiveRelevance)

        let nextState = CapgoLiveActivityAttributes.ContentState(data: contentData)
        let alert = alertConfiguration(from: alertConfig)
        if #available(iOS 16.2, *) {
            let content: ActivityContent<CapgoLiveActivityAttributes.ContentState>
            if let relevance {
                content = ActivityContent(state: nextState, staleDate: stale, relevanceScore: relevance)
            } else {
                content = ActivityContent(state: nextState, staleDate: stale)
            }
            if let alert {
                await activity.update(content, alertConfiguration: alert)
            } else {
                await activity.update(content)
            }
        } else {
            // iOS 16.1 only offers the contentState-based overload, which also takes the alert.
            await activity.update(using: nextState, alertConfiguration: alert)
        }
    }

    public func end(
        activityId: String,
        data: [String: Any]?,
        dismissalPolicy: String?,
        dismissAfter: Double?
    ) async throws {
        guard #available(iOS 16.1, *) else {
            throw CapgoLiveActivityError.unsupported
        }

        hydrateFromActivityKit()
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
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: policy)
        } else {
            await activity.end(using: finalState, dismissalPolicy: policy)
        }

        lock.lock()
        if var updated = activities[activityId] {
            updated.config["state"] = "ended"
            if let data { updated.config["data"] = data }
            updated.activity = nil
            activities[activityId] = updated
        }
        lock.unlock()
        removeMetadata(activityId: activityId)
    }

    public func allActivities() -> [[String: Any]] {
        hydrateFromActivityKit()
        lock.lock()
        defer { lock.unlock() }
        return activities.map { activityId, stored in
            var state = stored.config["state"] as? String ?? "active"
            if let activity = stored.activity as? Activity<CapgoLiveActivityAttributes> {
                state = stateString(activity.activityState)
            }
            var payload: [String: Any] = [
                "activityId": activityId,
                "state": state,
                "startDate": stored.config["startDate"] ?? 0,
                "data": stored.config["data"] ?? [:]
            ]
            if let pushToken = stored.pushToken, !pushToken.isEmpty {
                payload["pushToken"] = pushToken
            }
            return payload
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
        case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID():
            return .bool(value.boolValue)
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
    private func hydrateFromActivityKit() {
        let metadata = loadAllMetadata()
        for activity in Activity<CapgoLiveActivityAttributes>.activities {
            lock.lock()
            let activityId = activity.attributes.activityId
            let stateData = currentContentData(from: activity)
            let data = dictionary(from: stateData)
            let state = stateString(activity.activityState)
            if var existing = activities[activityId] {
                existing.activity = activity
                existing.config["state"] = state
                existing.config["data"] = data
                activities[activityId] = existing
            } else {
                // Recovered after an app restart: restore persisted metadata. startDate stays 0
                // (documented as unknown) only for activities started by an older plugin version.
                let stored = metadata[activityId] ?? [:]
                var config: [String: Any] = [
                    "state": state,
                    "startDate": stored["startDate"] ?? 0,
                    "data": data
                ]
                if let staleDate = stored["staleDate"] { config["staleDate"] = staleDate }
                if let relevanceScore = stored["relevanceScore"] { config["relevanceScore"] = relevanceScore }
                activities[activityId] = StoredActivity(config: config, pushToken: nil, activity: activity)
            }
            lock.unlock()
            observePushTokens(for: activity, activityId: activityId)
        }
    }

    private func normalizedRelevance(_ score: Double?) -> Double? {
        score.map { min(max($0 / 100.0, 0), 1) }
    }

    @available(iOS 16.1, *)
    private func alertConfiguration(from config: [String: Any]?) -> AlertConfiguration? {
        guard let config,
              let title = config["title"] as? String,
              let body = config["body"] as? String else {
            return nil
        }
        return AlertConfiguration(
            title: LocalizedStringResource(stringLiteral: title),
            body: LocalizedStringResource(stringLiteral: body),
            sound: .default
        )
    }

    @available(iOS 16.1, *)
    private func currentContentData(
        from activity: Activity<CapgoLiveActivityAttributes>
    ) -> [String: CapgoJSONValue] {
        if #available(iOS 16.2, *) {
            return activity.content.state.data
        }
        return activity.contentState.data
    }

    private func stateString(_ state: ActivityState) -> String {
        switch state {
        case .active:
            return "active"
        case .ended:
            return "ended"
        case .dismissed:
            return "dismissed"
        case .stale:
            return "stale"
        @unknown default:
            return "active"
        }
    }

    private func dictionary(from values: [String: CapgoJSONValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in values {
            result[key] = anyValue(from: value)
        }
        return result
    }

    private func anyValue(from value: CapgoJSONValue) -> Any {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .bool(let bool):
            return bool
        case .object(let object):
            return dictionary(from: object)
        case .array(let array):
            return array.map { anyValue(from: $0) }
        case .null:
            return NSNull()
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
