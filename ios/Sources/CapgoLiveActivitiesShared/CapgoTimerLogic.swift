import Foundation

public enum CapgoTimerLogic {
    /// Completed timers with `pausesOnReach` must stay at zero, not show wall-clock time.
    public static func usesPausedZeroWhenReached(pausesOnReach: Bool, target: Date, now: Date) -> Bool {
        pausesOnReach && target <= now
    }
}
