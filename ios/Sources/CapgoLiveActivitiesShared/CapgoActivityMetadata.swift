import Foundation

enum CapgoActivityMetadata {
    /// When an update omits `staleDate`, ignore a stored value that is already in the past.
    static func effectiveStaleDateMillis(requested: Double?, storedMillis: Double?, now: Date = Date()) -> Double? {
        if let requested {
            return requested
        }
        guard let storedMillis else {
            return nil
        }
        let storedDate = Date(timeIntervalSince1970: storedMillis / 1000)
        guard storedDate > now else {
            return nil
        }
        return storedMillis
    }
}
