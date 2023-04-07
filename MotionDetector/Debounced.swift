import SwiftUI

/// Debounces a potentially frequently-updated value to prevent
/// excess state updates caused by changes to its value.
class Debounced<T>: ObservableObject {
    /// The value that has been changed.
    @Published var input: T?

    /// The value that is reported periodically after being throttled.
    @Published var value: T?

    init(delay: Double) {
        $input.debounce(for: .seconds(delay),scheduler: RunLoop.main)
            .assign(to: &$value)
    }
}
