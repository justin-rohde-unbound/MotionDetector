import SwiftUI

/// Displays a time formatted as a duration in hours, minutes, seconds, and milliseconds.
struct FormattedTimeView: View {
    let time: Double

    var body: some View {
        let duration: Duration = .milliseconds(Int(time * 1000))
        let formattedDuration = duration.formatted(
            .time(pattern: .hourMinuteSecond(
                padHourToLength: 2,
                fractionalSecondsLength: 2
            ))
        )
        Text(formattedDuration)
    }
}

struct FormattedTimeView_Preview: PreviewProvider {
    static var previews: some View {
        FormattedTimeView(time: 1000.5)
    }
}
