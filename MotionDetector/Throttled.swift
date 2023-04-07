import SwiftUI

/// Throttles a potentially frequently-updated value to prevent
/// excess state updates caused by changes to its value.
class Throttled<T>: ObservableObject {
    /// The value that has been changed.
    @Published var input: T?

    /// The value that is reported periodically after being throttled.
    @Published var value: T?

    init(delay: Double) {
        $input.throttle(
            for: .seconds(delay),
            scheduler: RunLoop.main,
            latest: true
        ).assign(to: &$value)
    }
}
