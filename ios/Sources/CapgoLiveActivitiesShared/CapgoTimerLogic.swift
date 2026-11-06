import Foundation

public enum CapgoTimerLogic {
    /// Completed timers with `pausesOnReach` must stay at zero, not show wall-clock time.
    public static func usesPausedZeroWhenReached(pausesOnReach: Bool, target: Date, now: Date) -> Bool {
        pausesOnReach && target <= now
    }

    /// Range for `Text(timerInterval:pauseTime:countsDown:)` so the interval ends at `target` and pauses at zero.
    public static func pausedZeroTimerInterval(target: Date) -> ClosedRange<Date> {
        target.addingTimeInterval(-1)...target
    }
}
