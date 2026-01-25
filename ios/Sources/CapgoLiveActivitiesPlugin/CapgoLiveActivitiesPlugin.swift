import Foundation
import Capacitor
import ActivityKit
import AudioToolbox
import AVFoundation

/**
 * Timer sequence state for tracking workout timers
 */
struct TimerSequenceInfo {
    var options: [String: Any]
    var steps: [[String: Any]]
    var currentStepIndex: Int
    var remainingSeconds: Int
    var totalRemainingSeconds: Int
    var elapsedSeconds: Int
    var isRunning: Bool
    var isPaused: Bool
    var isComplete: Bool
    var currentLoop: Int
    var totalLoops: Int
    var timer: Timer?
    var startDate: Date
}

/**
 * Capacitor plugin for managing iOS Live Activities.
 * Requires iOS 16.1+ for Live Activities support.
 */
@objc(CapgoLiveActivitiesPlugin)
public class CapgoLiveActivitiesPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "1.0.0"
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
        // Timer sequence methods
        CAPPluginMethod(name: "startTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pauseTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resumeTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopTimerSequence", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "skipTimerStep", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "previousTimerStep", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTimerState", returnType: CAPPluginReturnPromise)
    ]

    private var activityStore: [String: Any] = [:]
    private var timerSequences: [String: TimerSequenceInfo] = [:]

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

        // Store the activity configuration
        let activityId = UUID().uuidString
        let activityConfig: [String: Any] = [
            "layout": layoutData,
            "dynamicIslandLayout": dynamicIslandData,
            "behavior": behavior ?? [:],
            "data": data,
            "staleDate": staleDate as Any,
            "relevanceScore": relevanceScore as Any,
            "startDate": Date().timeIntervalSince1970 * 1000
        ]
        activityStore[activityId] = activityConfig

        // Note: Actual ActivityKit implementation requires a Widget Extension
        // This plugin provides the bridge - the Widget Extension must be created separately
        call.resolve(["activityId": activityId])
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

        guard var config = activityStore[activityId] as? [String: Any] else {
            call.reject("Activity not found")
            return
        }

        // Update stored data
        config["data"] = data
        if let alertConfig = call.getObject("alertConfiguration") {
            config["alertConfiguration"] = alertConfig
        }
        if let staleDate = call.getDouble("staleDate") {
            config["staleDate"] = staleDate
        }
        if let relevanceScore = call.getDouble("relevanceScore") {
            config["relevanceScore"] = relevanceScore
        }
        activityStore[activityId] = config

        call.resolve()
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

        guard var config = activityStore[activityId] as? [String: Any] else {
            call.reject("Activity not found")
            return
        }

        // Mark as ended
        config["state"] = "ended"
        if let finalData = call.getObject("data") {
            config["data"] = finalData
        }
        activityStore[activityId] = config

        call.resolve()
    }

    @objc func getAllActivities(_ call: CAPPluginCall) {
        var activities: [[String: Any]] = []

        for (activityId, config) in activityStore {
            if let configDict = config as? [String: Any] {
                let activity: [String: Any] = [
                    "activityId": activityId,
                    "state": configDict["state"] as? String ?? "active",
                    "startDate": configDict["startDate"] ?? 0,
                    "data": configDict["data"] ?? [:]
                ]
                activities.append(activity)
            }
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

        // Save to shared App Group container
        if let containerURL = getSharedContainerURL() {
            let imagesDir = containerURL.appendingPathComponent("LiveActivityImages", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            let fileURL = imagesDir.appendingPathComponent("\(name).jpg")
            do {
                try jpegData.write(to: fileURL)
                call.resolve([
                    "success": true,
                    "imageName": name
                ])
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

            do {
                try FileManager.default.removeItem(at: imagesDir)
            } catch {
                // Directory might not exist, which is fine
            }
        }
        call.resolve()
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": pluginVersion])
    }

    // MARK: - Timer Sequence Methods

    @objc func startTimerSequence(_ call: CAPPluginCall) {
        guard let stepsArray = call.getArray("steps") as? [[String: Any]] else {
            call.reject("steps array is required")
            return
        }

        guard !stepsArray.isEmpty else {
            call.reject("steps array cannot be empty")
            return
        }

        let sequenceId = UUID().uuidString
        let title = call.getString("title") ?? "Timer"
        let loop = call.getBool("loop") ?? false
        let loopCount = call.getInt("loopCount") ?? 0
        let soundEnabled = call.getBool("soundEnabled") ?? true
        let vibrateEnabled = call.getBool("vibrateEnabled") ?? true
        let countdownBeeps = call.getBool("countdownBeeps") ?? true
        let tapUrl = call.getString("tapUrl")

        // Calculate total duration
        var totalDuration = 0
        for step in stepsArray {
            totalDuration += step["duration"] as? Int ?? 0
        }

        let firstStep = stepsArray[0]
        let firstDuration = firstStep["duration"] as? Int ?? 0

        var info = TimerSequenceInfo(
            options: [
                "title": title,
                "loop": loop,
                "loopCount": loopCount,
                "soundEnabled": soundEnabled,
                "vibrateEnabled": vibrateEnabled,
                "countdownBeeps": countdownBeeps,
                "tapUrl": tapUrl as Any
            ],
            steps: stepsArray,
            currentStepIndex: 0,
            remainingSeconds: firstDuration,
            totalRemainingSeconds: totalDuration,
            elapsedSeconds: 0,
            isRunning: true,
            isPaused: false,
            isComplete: false,
            currentLoop: 1,
            totalLoops: loopCount,
            timer: nil,
            startDate: Date()
        )

        timerSequences[sequenceId] = info

        // Start the timer
        startTimer(sequenceId: sequenceId)

        // Emit initial step change event
        emitTimerEvent(sequenceId: sequenceId, type: "stepChange")

        call.resolve(["sequenceId": sequenceId])
    }

    private func startTimer(sequenceId: String) {
        guard var info = timerSequences[sequenceId] else { return }

        info.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer(sequenceId: sequenceId)
        }
        timerSequences[sequenceId] = info
    }

    private func tickTimer(sequenceId: String) {
        guard var info = timerSequences[sequenceId], info.isRunning, !info.isPaused, !info.isComplete else { return }

        info.remainingSeconds -= 1
        info.totalRemainingSeconds -= 1
        info.elapsedSeconds += 1

        // Countdown beeps in last 3 seconds
        let countdownBeeps = info.options["countdownBeeps"] as? Bool ?? true
        if countdownBeeps && info.remainingSeconds <= 3 && info.remainingSeconds > 0 {
            playBeep()
        }

        timerSequences[sequenceId] = info

        // Emit tick event
        emitTimerEvent(sequenceId: sequenceId, type: "tick")

        // Check if current step is complete
        if info.remainingSeconds <= 0 {
            advanceToNextStep(sequenceId: sequenceId)
        }
    }

    private func advanceToNextStep(sequenceId: String) {
        guard var info = timerSequences[sequenceId] else { return }

        let soundEnabled = info.options["soundEnabled"] as? Bool ?? true
        let vibrateEnabled = info.options["vibrateEnabled"] as? Bool ?? true

        if info.currentStepIndex < info.steps.count - 1 {
            // Move to next step
            info.currentStepIndex += 1
            let nextStep = info.steps[info.currentStepIndex]
            info.remainingSeconds = nextStep["duration"] as? Int ?? 0
            timerSequences[sequenceId] = info

            if soundEnabled { playStepChangeSound() }
            if vibrateEnabled { vibrate() }

            emitTimerEvent(sequenceId: sequenceId, type: "stepChange")
        } else {
            // End of sequence
            let loop = info.options["loop"] as? Bool ?? false
            let loopCount = info.options["loopCount"] as? Int ?? 0

            if loop && (loopCount == 0 || info.currentLoop < loopCount) {
                // Loop back
                info.currentLoop += 1
                info.currentStepIndex = 0
                let firstStep = info.steps[0]
                info.remainingSeconds = firstStep["duration"] as? Int ?? 0

                // Recalculate total remaining
                var totalDuration = 0
                for step in info.steps {
                    totalDuration += step["duration"] as? Int ?? 0
                }
                info.totalRemainingSeconds = totalDuration

                timerSequences[sequenceId] = info

                if soundEnabled { playStepChangeSound() }
                if vibrateEnabled { vibrate() }

                emitTimerEvent(sequenceId: sequenceId, type: "loopComplete")
                emitTimerEvent(sequenceId: sequenceId, type: "stepChange")
            } else {
                // Complete
                info.isComplete = true
                info.isRunning = false
                info.timer?.invalidate()
                info.timer = nil
                timerSequences[sequenceId] = info

                if soundEnabled { playCompleteSound() }
                if vibrateEnabled { vibrateComplete() }

                emitTimerEvent(sequenceId: sequenceId, type: "complete")
            }
        }
    }

    @objc func pauseTimerSequence(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard var info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        info.isPaused = true
        timerSequences[sequenceId] = info

        emitTimerEvent(sequenceId: sequenceId, type: "paused")
        call.resolve()
    }

    @objc func resumeTimerSequence(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard var info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        info.isPaused = false
        timerSequences[sequenceId] = info

        emitTimerEvent(sequenceId: sequenceId, type: "resumed")
        call.resolve()
    }

    @objc func stopTimerSequence(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard var info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        info.timer?.invalidate()
        info.isRunning = false
        timerSequences[sequenceId] = info

        emitTimerEvent(sequenceId: sequenceId, type: "stopped")
        timerSequences.removeValue(forKey: sequenceId)
        call.resolve()
    }

    @objc func skipTimerStep(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard var info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        if info.currentStepIndex < info.steps.count - 1 {
            info.totalRemainingSeconds -= info.remainingSeconds
            info.elapsedSeconds += info.remainingSeconds
            info.currentStepIndex += 1
            let nextStep = info.steps[info.currentStepIndex]
            info.remainingSeconds = nextStep["duration"] as? Int ?? 0
            timerSequences[sequenceId] = info

            emitTimerEvent(sequenceId: sequenceId, type: "stepChange")
        }

        call.resolve()
    }

    @objc func previousTimerStep(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard var info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        if info.currentStepIndex > 0 {
            let currentStep = info.steps[info.currentStepIndex]
            let currentDuration = currentStep["duration"] as? Int ?? 0
            info.totalRemainingSeconds += currentDuration - info.remainingSeconds
            info.elapsedSeconds -= currentDuration - info.remainingSeconds

            info.currentStepIndex -= 1
            let prevStep = info.steps[info.currentStepIndex]
            let prevDuration = prevStep["duration"] as? Int ?? 0
            info.remainingSeconds = prevDuration
            info.totalRemainingSeconds += prevDuration
            info.elapsedSeconds -= prevDuration

            timerSequences[sequenceId] = info
            emitTimerEvent(sequenceId: sequenceId, type: "stepChange")
        }

        call.resolve()
    }

    @objc func getTimerState(_ call: CAPPluginCall) {
        guard let sequenceId = call.getString("sequenceId") else {
            call.reject("sequenceId is required")
            return
        }

        guard let info = timerSequences[sequenceId] else {
            call.reject("Timer sequence not found")
            return
        }

        call.resolve(buildStateDict(sequenceId: sequenceId, info: info))
    }

    private func buildStateDict(sequenceId: String, info: TimerSequenceInfo) -> [String: Any] {
        let currentStep = info.steps[info.currentStepIndex]
        return [
            "sequenceId": sequenceId,
            "isRunning": info.isRunning,
            "isPaused": info.isPaused,
            "isComplete": info.isComplete,
            "currentStepIndex": info.currentStepIndex,
            "totalSteps": info.steps.count,
            "currentStep": currentStep,
            "remainingSeconds": info.remainingSeconds,
            "totalRemainingSeconds": info.totalRemainingSeconds,
            "elapsedSeconds": info.elapsedSeconds,
            "currentLoop": info.currentLoop,
            "totalLoops": info.totalLoops
        ]
    }

    private func emitTimerEvent(sequenceId: String, type: String) {
        guard let info = timerSequences[sequenceId] else { return }

        let event: [String: Any] = [
            "type": type,
            "sequenceId": sequenceId,
            "state": buildStateDict(sequenceId: sequenceId, info: info)
        ]

        notifyListeners("timerSequenceEvent", data: event)
    }

    // MARK: - Sound and Haptics

    private func playBeep() {
        AudioServicesPlaySystemSound(1057) // Tock sound
    }

    private func playStepChangeSound() {
        AudioServicesPlaySystemSound(1007) // SMS received
    }

    private func playCompleteSound() {
        AudioServicesPlaySystemSound(1025) // New mail
    }

    private func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func vibrateComplete() {
        // Multiple vibrations for complete
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    // MARK: - Helpers

    private func getSharedContainerURL() -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let groupId = "group.\(bundleId).liveactivities"
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    }
}
