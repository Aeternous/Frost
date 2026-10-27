import Foundation

/// Turns raw lid angles into how far the lid has closed and whether it's moving.
///
/// "Closed by" is measured from where the lid normally sits, so pausing mid-close and then
/// closing further picks up where it left off. The effect is only shown while the lid is
/// moving; once it is held still the caller fades back to the normal view.
struct TiltTracker {
    var holdTime = 0.8          // seconds of stillness before the effect fades out
    var rebaseAfter = 8.0       // seconds of stillness before the current angle becomes the new normal
    var moveThreshold = 1.0     // degrees of change that count as movement

    private(set) var rest: Double?
    private var anchor = 0.0
    private var lastMove = -Double.infinity

    /// Returns degrees closed from the resting angle, and whether the lid is moving.
    mutating func update(angle: Double, now: TimeInterval) -> (closedBy: Double, moving: Bool) {
        guard rest != nil else {
            rest = angle
            anchor = angle
            return (0, false)
        }
        if abs(angle - anchor) >= moveThreshold {
            anchor = angle
            lastMove = now
        }
        let still = now - lastMove
        // "Normal" is where the lid last settled, not the widest it has been: briefly opening
        // wider and coming back to the usual angle must not count as closing.
        if still >= rebaseAfter { rest = angle }
        return (max(0, rest! - angle), still < holdTime)
    }

    mutating func reset() { rest = nil }
}
