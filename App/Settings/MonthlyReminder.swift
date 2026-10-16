import Foundation
import UserNotifications
import FoldL10n

/// F6: a local notification once a month suggesting a check-up. Nothing leaves the device.
enum MonthlyReminder {
    static let identifier = "foldcheck.monthlyReminder"

    /// The same day each month as `date` (capped at 28 so every month has it), at 10:00.
    static func components(startingFrom date: Date, calendar: Calendar = .current) -> DateComponents {
        var components = DateComponents()
        components.day = min(calendar.component(.day, from: date), 28)
        components.hour = 10
        components.minute = 0
        return components
    }

    /// Asks for permission if needed and schedules the reminder in `language`.
    /// Returns false when notifications are off for FoldCheck.
    static func enable(language: AppLanguage, from date: Date = .now) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        let content = UNMutableNotificationContent()
        content.title = L10nKey.reminderTitle.text(in: language)
        content.body = L10nKey.reminderBody.text(in: language)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components(startingFrom: date), repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
