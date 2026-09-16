// Local iOS bill reminders.
// Supabase stores the preference; iOS owns delivery.

import Foundation
import UserNotifications


enum BillReminderError:
    LocalizedError {

    case notificationsDenied
    case missingDueDate
    case dueDatePassed

    var errorDescription:
        String? {

        switch self {

        case .notificationsDenied:

            return
                "Notifications are turned off for AI Document & Bill Explainer. Enable notifications in iPhone Settings to receive bill reminders."

        case .missingDueDate:

            return
                "This document does not have a detected due date."

        case .dueDatePassed:

            return
                "This bill's detected due date has already passed."
        }
    }
}


actor BillReminderService {

    static let shared =
        BillReminderService()

    static let threadIdentifier =
        "bill-reminders"

    static let categoryIdentifier =
        "BILL_REMINDER"

    private let center =
        UNUserNotificationCenter
            .current()


    private init() {

        center.delegate =
            BillNotificationPresentationDelegate
                .shared

        configureCategory()
    }


    // Permission

    func authorizationStatus()
        async
        -> UNAuthorizationStatus {

        let settings =
            await center
                .notificationSettings()

        return
            settings
                .authorizationStatus
    }


    func requestAuthorizationIfNeeded()
        async throws
        -> Bool {

        let status =
            await authorizationStatus()


        switch status {

        case .authorized,
             .provisional,
             .ephemeral:

            return true


        case .denied:

            throw
                BillReminderError
                    .notificationsDenied


        case .notDetermined:

            let granted =
                try await center
                    .requestAuthorization(
                        options: [
                            .alert,
                            .sound,
                            .badge
                        ]
                    )

            if !granted {

                throw
                    BillReminderError
                        .notificationsDenied
            }

            return true


        @unknown default:

            return false
        }
    }


    // Schedule

    func schedule(
        documentID:
            UUID,
        documentName:
            String,
        dueDate:
            Date,
        daysBefore:
            Int,
        hour:
            Int
    ) async throws {

        _ =
            try await
                requestAuthorizationIfNeeded()


        try await scheduleAuthorized(
            documentID:
                documentID,
            documentName:
                documentName,
            dueDate:
                dueDate,
            daysBefore:
                daysBefore,
            hour:
                hour
        )
    }


    private func scheduleAuthorized(
        documentID:
            UUID,
        documentName:
            String,
        dueDate:
            Date,
        daysBefore:
            Int,
        hour:
            Int
    ) async throws {

        let calendar =
            Calendar.current

        let today =
            calendar
                .startOfDay(
                    for:
                        Date()
                )

        let dueDay =
            calendar
                .startOfDay(
                    for:
                        dueDate
                )


        guard
            dueDay
            >=
            today
        else {

            await cancel(
                documentID:
                    documentID
            )

            throw
                BillReminderError
                    .dueDatePassed
        }


        let targetDay =
            calendar.date(
                byAdding:
                    .day,
                value:
                    -daysBefore,
                to:
                    dueDay
            )
            ??
            dueDay


        var targetComponents =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from:
                    targetDay
            )

        targetComponents.hour =
            hour

        targetComponents.minute =
            0


        let requestedTarget =
            calendar.date(
                from:
                    targetComponents
            )
            ??
            targetDay


        let content =
            UNMutableNotificationContent()

        content.title =
            notificationTitle(
                dueDate:
                    dueDay
            )

        content.body =
            notificationBody(
                documentName:
                    documentName,
                dueDate:
                    dueDay
            )

        content.sound =
            .default

        content.threadIdentifier =
            Self.threadIdentifier

        content.categoryIdentifier =
            Self.categoryIdentifier

        content.userInfo = [
            "kind":
                "bill-reminder",
            "document_id":
                documentID
                    .uuidString,
            "due_date":
                isoDateString(
                    dueDay
                )
        ]


        let trigger:
            UNNotificationTrigger


        if requestedTarget
            <=
            Date() {

            // The requested lead time has already passed but the
            // bill is still due. Deliver a useful reminder shortly
            // instead of silently failing to schedule anything.
            trigger =
                UNTimeIntervalNotificationTrigger(
                    timeInterval:
                        5,
                    repeats:
                        false
                )

        } else {

            trigger =
                UNCalendarNotificationTrigger(
                    dateMatching:
                        targetComponents,
                    repeats:
                        false
                )
        }


        let request =
            UNNotificationRequest(
                identifier:
                    identifier(
                        documentID
                    ),
                content:
                    content,
                trigger:
                    trigger
            )


        center
            .removePendingNotificationRequests(
                withIdentifiers: [
                    identifier(
                        documentID
                    )
                ]
            )


        try await center
            .add(
                request
            )
    }


    // Synchronize Saved Preferences

    func synchronizeIfAuthorized(
        documents:
            [HistoryDocument]
    ) async {

        let status =
            await authorizationStatus()


        guard
            status == .authorized
            ||
            status == .provisional
            ||
            status == .ephemeral
        else {

            return
        }


        for document
            in documents {

            guard
                document
                    .reminderEnabled,
                let dueDate =
                    document
                        .dueDate
            else {

                await cancel(
                    documentID:
                        document.id
                )

                continue
            }


            do {

                try await
                    scheduleAuthorized(
                        documentID:
                            document.id,
                        documentName:
                            document
                                .resolvedDisplayName,
                        dueDate:
                            dueDate,
                        daysBefore:
                            document
                                .reminderDaysBefore,
                        hour:
                            document
                                .reminderHour
                    )

            } catch {

                // Synchronization is best-effort. A past due date
                // simply has no pending local reminder.
            }
        }
    }


    // Cancel / Inspect

    func cancel(
        documentID:
            UUID
    ) async {

        let id =
            identifier(
                documentID
            )


        center
            .removePendingNotificationRequests(
                withIdentifiers: [
                    id
                ]
            )


        center
            .removeDeliveredNotifications(
                withIdentifiers: [
                    id
                ]
            )
    }


    func isScheduled(
        documentID:
            UUID
    ) async
        -> Bool {

        let requests =
            await center
                .pendingNotificationRequests()


        return
            requests
                .contains {
                    $0.identifier
                    ==
                    identifier(
                        documentID
                    )
                }
    }


    // Test Notification

    func sendTestNotification(
        documentName:
            String
    ) async throws {

        _ =
            try await
                requestAuthorizationIfNeeded()


        let content =
            UNMutableNotificationContent()

        content.title =
            "Bill reminder test"

        content.body =
            "\(documentName) reminders are ready."

        content.sound =
            .default

        content.threadIdentifier =
            Self.threadIdentifier


        let request =
            UNNotificationRequest(
                identifier:
                    "bill-reminder-test-\(UUID().uuidString)",
                content:
                    content,
                trigger:
                    UNTimeIntervalNotificationTrigger(
                        timeInterval:
                            3,
                        repeats:
                            false
                    )
            )


        try await center
            .add(
                request
            )
    }


    // Helpers

    private func identifier(
        _ documentID:
            UUID
    ) -> String {

        "bill-reminder-\(documentID.uuidString)"
    }


    private func notificationTitle(
        dueDate:
            Date
    ) -> String {

        let calendar =
            Calendar.current

        let days =
            calendar
                .dateComponents(
                    [
                        .day
                    ],
                    from:
                        calendar
                            .startOfDay(
                                for:
                                    Date()
                            ),
                    to:
                        calendar
                            .startOfDay(
                                for:
                                    dueDate
                            )
                )
                .day
            ??
            0


        if days <= 0 {

            return
                "Bill due today"
        }


        return
            "Bill due soon"
    }


    private func notificationBody(
        documentName:
            String,
        dueDate:
            Date
    ) -> String {

        let calendar =
            Calendar.current

        let days =
            calendar
                .dateComponents(
                    [
                        .day
                    ],
                    from:
                        calendar
                            .startOfDay(
                                for:
                                    Date()
                            ),
                    to:
                        calendar
                            .startOfDay(
                                for:
                                    dueDate
                            )
                )
                .day
            ??
            0


        switch days {

        case ...0:

            return
                "\(documentName) is due today."

        case 1:

            return
                "\(documentName) is due tomorrow."

        default:

            return
                "\(documentName) is due in \(days) days on \(dueDate.formatted(date: .abbreviated, time: .omitted))."
        }
    }


    private func isoDateString(
        _ date:
            Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone.current

        formatter.dateFormat =
            "yyyy-MM-dd"


        return
            formatter.string(
                from:
                    date
            )
    }


    private nonisolated func configureCategory() {

        let openAction =
            UNNotificationAction(
                identifier:
                    "OPEN_BILL",
                title:
                    "Open App",
                options: [
                    .foreground
                ]
            )


        let category =
            UNNotificationCategory(
                identifier:
                    Self.categoryIdentifier,
                actions: [
                    openAction
                ],
                intentIdentifiers: [],
                options: []
            )


        UNUserNotificationCenter
            .current()
            .setNotificationCategories(
                [
                    category
                ]
            )
    }
}
