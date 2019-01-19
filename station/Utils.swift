import Foundation

public class Utils {
    func timeSince(date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        var output = "Updated ";
        // show date if the tag has not been seen for 24h
        if elapsed >= 24 * 60 * 60 {
            output += date.description
        } else {
            let seconds = elapsed % 60
            let minutes = (elapsed / 60) % 60
            let hours   = (elapsed / (60*60)) % 24
            if hours > 0 {
                output += String(hours) + " h "
            }
            if minutes > 0 {
                output += String(minutes) + " min "
            }
            output += String(seconds) + " s ago"
        }
        return output;
    }
}
