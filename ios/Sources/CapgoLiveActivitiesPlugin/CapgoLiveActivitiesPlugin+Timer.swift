import Foundation
import Capacitor
import AudioToolbox

// MARK: - Timer Sequence Methods
extension CapgoLiveActivitiesPlugin {

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

    func startTimer(sequenceId: String) {
        guard var info = timerSequences[sequenceId] else { return }

        info.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer(sequenceId: sequenceId)
        }
        timerSequences[sequenceId] = info
    }

    func tickTimer(sequenceId: String) {
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

    func advanceToNextStep(sequenceId: String) {
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

    func buildStateDict(sequenceId: String, info: TimerSequenceInfo) -> [String: Any] {
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

    func emitTimerEvent(sequenceId: String, type: String) {
        guard let info = timerSequences[sequenceId] else { return }

        let event: [String: Any] = [
            "type": type,
            "sequenceId": sequenceId,
            "state": buildStateDict(sequenceId: sequenceId, info: info)
        ]

        notifyListeners("timerSequenceEvent", data: event)
    }

    // MARK: - Sound and Haptics

    func playBeep() {
        AudioServicesPlaySystemSound(1057) // Tock sound
    }

    func playStepChangeSound() {
        AudioServicesPlaySystemSound(1007) // SMS received
    }

    func playCompleteSound() {
        AudioServicesPlaySystemSound(1025) // New mail
    }

    func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    func vibrateComplete() {
        // Multiple vibrations for complete
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}
