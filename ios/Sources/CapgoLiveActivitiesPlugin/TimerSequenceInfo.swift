import Foundation

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
