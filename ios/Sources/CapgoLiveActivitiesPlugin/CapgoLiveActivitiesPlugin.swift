import Foundation
import Capacitor
import ActivityKit
#if canImport(CapgoLiveActivitiesShared)
import CapgoLiveActivitiesShared
#endif

/**
 * Capacitor plugin for managing iOS Live Activities.
 * Requires iOS 16.1+ for Live Activities support.
 */
@objc(CapgoLiveActivitiesPlugin)
public class CapgoLiveActivitiesPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "1.2.0"
    public let identifier = "CapgoLiveActivitiesPlugin"
    public let jsName = "CapgoLiveActivities"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "areActivitiesSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAllActivities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "saveImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listImages", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cleanupImages", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pauseTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resumeTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "skipTimerStep", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "previousTimerStep", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTimerState", returnType: CAPPluginReturnPromise)
    ]

    var timerSequences: [String: TimerSequenceInfo] = [:]

    @objc func areActivitiesSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.1, *) {
            let supported = ActivityAuthorizationInfo().areActivitiesEnabled
            if supported {
                call.resolve(["supported": true])
            } else {
                call.resolve([
                    "supported": false,
                    "reason": "Live Activities are disabled in Settings"
                ])
            }
        } else {
            call.resolve([
                "supported": false,
                "reason": "iOS 16.1 or later is required for Live Activities"
            ])
        }
    }

    @objc func startActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities require iOS 16.1 or later")
            return
        }

        guard let layoutData = call.getObject("layout"),
              let dynamicIslandData = call.getObject("dynamicIslandLayout"),
              let data = call.getObject("data") else {
            call.reject("layout, dynamicIslandLayout, and data are required")
            return
        }

        let behavior = call.getObject("behavior")
        let staleDate = call.getDouble("staleDate")
        let relevanceScore = call.getDouble("relevanceScore")

        let activityId = UUID().uuidString
        let appGroupId = appGroupIdentifier()

        do {
            try CapgoLiveActivityManager.shared.start(
                activityId: activityId,
                layout: layoutData,
                dynamicIslandLayout: dynamicIslandData,
                behavior: behavior,
                data: data,
                staleDate: staleDate,
                relevanceScore: relevanceScore,
                appGroupId: appGroupId
            )
            call.resolve(["activityId": activityId])
        } catch CapgoLiveActivityError.invalidOptions(let message) {
            call.reject(message)
        } catch {
            call.reject("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    @objc func updateActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities require iOS 16.1 or later")
            return
        }

        guard let activityId = call.getString("activityId"),
              let data = call.getObject("data") else {
            call.reject("activityId and data are required")
            return
        }

        let staleDate = call.getDouble("staleDate")
        let relevanceScore = call.getDouble("relevanceScore")
        let alertConfiguration = call.getObject("alertConfiguration")

        Task {
            do {
                try await CapgoLiveActivityManager.shared.update(
                    activityId: activityId,
                    data: data,
                    staleDate: staleDate,
                    relevanceScore: relevanceScore,
                    alertConfig: alertConfiguration
                )
                call.resolve()
            } catch CapgoLiveActivityError.notFound {
                call.reject("Activity not found")
            } catch CapgoLiveActivityError.invalidOptions(let message) {
                call.reject(message)
            } catch {
                call.reject("Failed to update Live Activity: \(error.localizedDescription)")
            }
        }
    }

    @objc func endActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities require iOS 16.1 or later")
            return
        }

        guard let activityId = call.getString("activityId") else {
            call.reject("activityId is required")
            return
        }

        let dismissalPolicy = call.getString("dismissalPolicy")
        let dismissAfter = call.getDouble("dismissAfter")
        let finalData = call.getObject("data")

        Task {
            do {
                try await CapgoLiveActivityManager.shared.end(
                    activityId: activityId,
                    data: finalData,
                    dismissalPolicy: dismissalPolicy,
                    dismissAfter: dismissAfter
                )
                call.resolve()
            } catch CapgoLiveActivityError.notFound {
                call.reject("Activity not found")
            } catch {
                call.reject("Failed to end Live Activity: \(error.localizedDescription)")
            }
        }
    }

    @objc func getAllActivities(_ call: CAPPluginCall) {
        let activities = CapgoLiveActivityManager.shared.allActivities().map { activity -> [String: Any] in
            var payload: [String: Any] = [
                "activityId": activity["activityId"] ?? "",
                "state": activity["state"] ?? "active",
                "startDate": activity["startDate"] ?? 0,
                "data": activity["data"] ?? [:]
            ]
            if let pushToken = activity["pushToken"] as? String, !pushToken.isEmpty {
                payload["pushToken"] = pushToken
            }
            return payload
        }
        call.resolve(["activities": activities])
    }

    @objc func saveImage(_ call: CAPPluginCall) {
        guard let imageData = call.getString("imageData"),
              let name = call.getString("name") else {
            call.reject("imageData and name are required")
            return
        }

        let compressionQuality = call.getFloat("compressionQuality") ?? 0.8

        guard let data = Data(base64Encoded: imageData),
              let image = UIImage(data: data) else {
            call.reject("Invalid image data")
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: CGFloat(compressionQuality)) else {
            call.reject("Failed to compress image")
            return
        }

        if let containerURL = getSharedContainerURL() {
            let imagesDir = containerURL.appendingPathComponent("LiveActivityImages", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            let fileURL = imagesDir.appendingPathComponent("\(name).jpg")
            do {
                try jpegData.write(to: fileURL)
                call.resolve(["success": true, "imageName": name])
            } catch {
                call.reject("Failed to save image: \(error.localizedDescription)")
            }
        } else {
            call.reject("Shared container not available. Ensure App Group is configured.")
        }
    }

    @objc func removeImage(_ call: CAPPluginCall) {
        guard let name = call.getString("name") else {
            call.reject("name is required")
            return
        }

        if let containerURL = getSharedContainerURL() {
            let fileURL = containerURL
                .appendingPathComponent("LiveActivityImages", isDirectory: true)
                .appendingPathComponent("\(name).jpg")

            do {
                try FileManager.default.removeItem(at: fileURL)
                call.resolve(["success": true])
            } catch {
                call.resolve(["success": false])
            }
        } else {
            call.reject("Shared container not available")
        }
    }

    @objc func listImages(_ call: CAPPluginCall) {
        if let containerURL = getSharedContainerURL() {
            let imagesDir = containerURL.appendingPathComponent("LiveActivityImages", isDirectory: true)

            do {
                let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
                let imageNames = files
                    .filter { $0.pathExtension == "jpg" }
                    .map { $0.deletingPathExtension().lastPathComponent }
                call.resolve(["images": imageNames])
            } catch {
                call.resolve(["images": []])
            }
        } else {
            call.resolve(["images": []])
        }
    }

    @objc func cleanupImages(_ call: CAPPluginCall) {
        if let containerURL = getSharedContainerURL() {
            let imagesDir = containerURL.appendingPathComponent("LiveActivityImages", isDirectory: true)
            try? FileManager.default.removeItem(at: imagesDir)
        }
        call.resolve()
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": pluginVersion])
    }

    func getSharedContainerURL() -> URL? {
        guard let groupId = appGroupIdentifier() else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    }

    func appGroupIdentifier() -> String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        return "group.\(bundleId).liveactivities"
    }
}
