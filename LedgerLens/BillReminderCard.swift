import SwiftUI
import UIKit
import UserNotifications


struct BillReminderCard:
    View {

    let document:
        HistoryDocument

    let onUpdated:
        (HistoryDocument) -> Void


    @State private var isEnabled:
        Bool

    @State private var selectedDays:
        Int

    @State private var selectedHour:
        Int

    @State private var authorizationStatus:
        UNAuthorizationStatus =
        .notDetermined

    @State private var isSaving =
        false

    @State private var isSendingTest =
        false

    @State private var errorMessage:
        String?

    @State private var confirmationMessage:
        String?


    init(
        document:
            HistoryDocument,
        onUpdated:
            @escaping (HistoryDocument) -> Void
    ) {

        self.document =
            document

        self.onUpdated =
            onUpdated


        _isEnabled =
            State(
                initialValue:
                    document
                        .reminderEnabled
            )

        _selectedDays =
            State(
                initialValue:
                    document
                        .reminderDaysBefore
            )

        _selectedHour =
            State(
                initialValue:
                    document
                        .reminderHour
            )
    }


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                15
        ) {

            header


            if let dueDate =
                document
                    .dueDate {

                dueDateSummary(
                    dueDate
                )


                if dueDate
                    >=
                    Calendar.current
                        .startOfDay(
                            for:
                                Date()
                        ) {

                    reminderControls(
                        dueDate
                    )

                } else {

                    Label(
                        "This detected due date has passed, so a new reminder cannot be scheduled.",
                        systemImage:
                            "clock.badge.xmark"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else {

                Label(
                    "No due date was detected in this document.",
                    systemImage:
                        "calendar.badge.questionmark"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            if authorizationStatus
                ==
                .denied {

                permissionDeniedCard

            } else {

                Button {

                    sendTestNotification()

                } label: {

                    HStack {

                        if isSendingTest {

                            ProgressView()

                        } else {

                            Image(
                                systemName:
                                    "bell.and.waves.left.and.right"
                            )
                        }


                        Text(
                            "Test Notifications"
                        )
                    }
                }
                .buttonStyle(
                    .bordered
                )
                .disabled(
                    isSendingTest
                )
            }


            if let confirmationMessage {

                Label(
                    confirmationMessage,
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(
                    .caption
                    .weight(.semibold)
                )
                .foregroundStyle(
                    .green
                )
            }


            if let errorMessage {

                Text(
                    errorMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .red
                )
            }
        }
        .padding(
            17
        )
        .background(
            Color.orange
                .opacity(
                    0.055
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
            .stroke(
                isEnabled
                ? Color.orange
                    .opacity(
                        0.24
                    )
                : Color.primary
                    .opacity(
                        0.06
                    )
            )
        }
        .task {

            authorizationStatus =
                await BillReminderService
                    .shared
                    .authorizationStatus()
        }
        .onChange(
            of:
                selectedDays
        ) {
            _,
            _ in

            if isEnabled {

                reschedule()
            }
        }
        .onChange(
            of:
                selectedHour
        ) {
            _,
            _ in

            if isEnabled {

                reschedule()
            }
        }
    }


    // Header

    private var header:
        some View {

        HStack(
            alignment:
                .top,
            spacing:
                12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.orange
                            .opacity(
                                0.12
                            )
                    )
                    .frame(
                        width:
                            44,
                        height:
                            44
                    )


                Image(
                    systemName:
                        isEnabled
                        ? "bell.badge.fill"
                        : "bell"
                )
                .foregroundStyle(
                    .orange
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Bill reminder"
                )
                .font(
                    .headline
                )


                Text(
                    "Get a local iPhone notification before this bill is due."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if isEnabled {

                Text(
                    "ON"
                )
                .font(
                    .caption2
                    .weight(.bold)
                )
                .foregroundStyle(
                    .green
                )
                .padding(
                    .horizontal,
                    8
                )
                .padding(
                    .vertical,
                    5
                )
                .background(
                    Color.green
                        .opacity(
                            0.10
                        )
                )
                .clipShape(
                    Capsule()
                )
            }
        }
    }


    // Due Date

    private func dueDateSummary(
        _ dueDate:
            Date
    ) -> some View {

        HStack(
            spacing:
                12
        ) {

            Image(
                systemName:
                    "calendar.badge.exclamationmark"
            )
            .font(
                .title3
            )
            .foregroundStyle(
                dueTint(
                    dueDate
                )
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    dueText(
                        dueDate
                    )
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Text(
                    dueDate
                        .formatted(
                            date:
                                .long,
                            time:
                                .omitted
                        )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()
        }
        .padding(
            12
        )
        .background(
            dueTint(
                dueDate
            )
            .opacity(
                0.07
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    15,
                style:
                    .continuous
            )
        )
    }


    // Controls

    private func reminderControls(
        _ dueDate:
            Date
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            Divider()


            HStack {

                Text(
                    "Remind me"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Spacer()


                Picker(
                    "Lead time",
                    selection:
                        $selectedDays
                ) {

                    Text(
                        "Due day"
                    )
                    .tag(
                        0
                    )

                    Text(
                        "1 day before"
                    )
                    .tag(
                        1
                    )

                    Text(
                        "3 days before"
                    )
                    .tag(
                        3
                    )

                    Text(
                        "7 days before"
                    )
                    .tag(
                        7
                    )
                }
                .pickerStyle(
                    .menu
                )
                .disabled(
                    isSaving
                )
            }


            HStack {

                Text(
                    "Notification time"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Spacer()


                Picker(
                    "Time",
                    selection:
                        $selectedHour
                ) {

                    Text(
                        "8:00 AM"
                    )
                    .tag(
                        8
                    )

                    Text(
                        "9:00 AM"
                    )
                    .tag(
                        9
                    )

                    Text(
                        "12:00 PM"
                    )
                    .tag(
                        12
                    )

                    Text(
                        "6:00 PM"
                    )
                    .tag(
                        18
                    )
                }
                .pickerStyle(
                    .menu
                )
                .disabled(
                    isSaving
                )
            }


            Button {

                if isEnabled {

                    disableReminder()

                } else {

                    enableReminder(
                        dueDate:
                            dueDate
                    )
                }

            } label: {

                HStack {

                    if isSaving {

                        ProgressView()
                            .tint(
                                .white
                            )

                    } else {

                        Image(
                            systemName:
                                isEnabled
                                ? "bell.slash.fill"
                                : "bell.badge.fill"
                        )
                    }


                    Text(
                        isEnabled
                        ? "Turn Off Reminder"
                        : "Set Bill Reminder"
                    )


                    Spacer()
                }
                .font(
                    .headline
                )
                .padding(
                    14
                )
                .foregroundStyle(
                    .white
                )
                .background(
                    isEnabled
                    ? Color.secondary
                    : Color.orange
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            15,
                        style:
                            .continuous
                    )
                )
            }
            .buttonStyle(
                .plain
            )
            .disabled(
                isSaving
            )


            if isEnabled {

                Label(
                    reminderSummary(
                        dueDate
                    ),
                    systemImage:
                        "clock.fill"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    // Permission Denied

    private var permissionDeniedCard:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {

            Text(
                "Notifications are disabled"
            )
            .font(
                .subheadline
                .weight(.semibold)
            )


            Text(
                "Your reminder preference can only deliver notifications after notifications are enabled for this app in iPhone Settings."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Button {

                guard
                    let url =
                        URL(
                            string:
                                UIApplication
                                    .openSettingsURLString
                        )
                else {
                    return
                }


                UIApplication
                    .shared
                    .open(
                        url
                    )

            } label: {

                Label(
                    "Open iPhone Settings",
                    systemImage:
                        "gear"
                )
            }
            .buttonStyle(
                .bordered
            )
        }
        .padding(
            12
        )
        .background(
            Color.red
                .opacity(
                    0.055
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    14,
                style:
                    .continuous
            )
        )
    }


    // Actions

    private func enableReminder(
        dueDate:
            Date
    ) {

        guard
            !isSaving
        else {
            return
        }


        isSaving =
            true

        errorMessage =
            nil

        confirmationMessage =
            nil


        Task {

            do {

                try await
                    BillReminderService
                        .shared
                        .schedule(
                            documentID:
                                document
                                    .id,
                            documentName:
                                document
                                    .resolvedDisplayName,
                            dueDate:
                                dueDate,
                            daysBefore:
                                selectedDays,
                            hour:
                                selectedHour
                        )


                do {

                    try await
                        DocumentHistoryService
                            .shared
                            .updateReminderPreference(
                                id:
                                    document
                                        .id,
                                enabled:
                                    true,
                                daysBefore:
                                    selectedDays,
                                hour:
                                    selectedHour
                            )

                } catch {

                    await BillReminderService
                        .shared
                        .cancel(
                            documentID:
                                document
                                    .id
                        )

                    throw error
                }


                let refreshed =
                    try await
                        DocumentHistoryService
                            .shared
                            .fetchDocument(
                                id:
                                    document
                                        .id
                            )


                let status =
                    await BillReminderService
                        .shared
                        .authorizationStatus()


                await MainActor.run {

                    authorizationStatus =
                        status

                    isEnabled =
                        true

                    confirmationMessage =
                        "Reminder scheduled."

                    isSaving =
                        false

                    onUpdated(
                        refreshed
                    )
                }


            } catch {

                let status =
                    await BillReminderService
                        .shared
                        .authorizationStatus()


                await MainActor.run {

                    authorizationStatus =
                        status

                    errorMessage =
                        error
                            .localizedDescription

                    isEnabled =
                        false

                    isSaving =
                        false
                }
            }
        }
    }


    private func disableReminder() {

        guard
            !isSaving
        else {
            return
        }


        isSaving =
            true

        errorMessage =
            nil

        confirmationMessage =
            nil


        Task {

            do {

                try await
                    DocumentHistoryService
                        .shared
                        .updateReminderPreference(
                            id:
                                document
                                    .id,
                            enabled:
                                false,
                            daysBefore:
                                selectedDays,
                            hour:
                                selectedHour
                        )


                await BillReminderService
                    .shared
                    .cancel(
                        documentID:
                            document
                                .id
                    )


                let refreshed =
                    try await
                        DocumentHistoryService
                            .shared
                            .fetchDocument(
                                id:
                                    document
                                        .id
                            )


                await MainActor.run {

                    isEnabled =
                        false

                    confirmationMessage =
                        "Reminder turned off."

                    isSaving =
                        false

                    onUpdated(
                        refreshed
                    )
                }


            } catch {

                await MainActor.run {

                    errorMessage =
                        error
                            .localizedDescription

                    isSaving =
                        false
                }
            }
        }
    }


    private func reschedule() {

        guard
            isEnabled,
            !isSaving,
            let dueDate =
                document
                    .dueDate
        else {
            return
        }


        isSaving =
            true

        errorMessage =
            nil

        confirmationMessage =
            nil


        Task {

            do {

                try await
                    BillReminderService
                        .shared
                        .schedule(
                            documentID:
                                document
                                    .id,
                            documentName:
                                document
                                    .resolvedDisplayName,
                            dueDate:
                                dueDate,
                            daysBefore:
                                selectedDays,
                            hour:
                                selectedHour
                        )


                try await
                    DocumentHistoryService
                        .shared
                        .updateReminderPreference(
                            id:
                                document
                                    .id,
                            enabled:
                                true,
                            daysBefore:
                                selectedDays,
                            hour:
                                selectedHour
                        )


                let refreshed =
                    try await
                        DocumentHistoryService
                            .shared
                            .fetchDocument(
                                id:
                                    document
                                        .id
                            )


                await MainActor.run {

                    confirmationMessage =
                        "Reminder updated."

                    isSaving =
                        false

                    onUpdated(
                        refreshed
                    )
                }


            } catch {

                await MainActor.run {

                    errorMessage =
                        error
                            .localizedDescription

                    isSaving =
                        false
                }
            }
        }
    }


    private func sendTestNotification() {

        guard
            !isSendingTest
        else {
            return
        }


        isSendingTest =
            true

        errorMessage =
            nil

        confirmationMessage =
            nil


        Task {

            do {

                try await
                    BillReminderService
                        .shared
                        .sendTestNotification(
                            documentName:
                                document
                                    .resolvedDisplayName
                        )


                let status =
                    await BillReminderService
                        .shared
                        .authorizationStatus()


                await MainActor.run {

                    authorizationStatus =
                        status

                    confirmationMessage =
                        "Test notification will arrive in a few seconds."

                    isSendingTest =
                        false
                }

            } catch {

                let status =
                    await BillReminderService
                        .shared
                        .authorizationStatus()


                await MainActor.run {

                    authorizationStatus =
                        status

                    errorMessage =
                        error
                            .localizedDescription

                    isSendingTest =
                        false
                }
            }
        }
    }


    // Copy

    private func dueText(
        _ dueDate:
            Date
    ) -> String {

        let days =
            daysUntil(
                dueDate
            )


        switch days {

        case ..<0:

            return
                "Past due"

        case 0:

            return
                "Due today"

        case 1:

            return
                "Due tomorrow"

        default:

            return
                "Due in \(days) days"
        }
    }


    private func reminderSummary(
        _ dueDate:
            Date
    ) -> String {

        let lead:
            String


        switch selectedDays {

        case 0:

            lead =
                "on the due date"

        case 1:

            lead =
                "1 day before"

        default:

            lead =
                "\(selectedDays) days before"
        }


        let timeDate =
            Calendar.current
                .date(
                    from:
                        DateComponents(
                            year:
                                2001,
                            month:
                                1,
                            day:
                                1,
                            hour:
                                selectedHour
                        )
                )


        let time =
            timeDate?
                .formatted(
                    date:
                        .omitted,
                    time:
                        .shortened
                )
        ??
        "\(selectedHour):00"


        return
            "Scheduled \(lead) at \(time)."
    }


    private func dueTint(
        _ dueDate:
            Date
    ) -> Color {

        switch daysUntil(
            dueDate
        ) {

        case ..<0:
            return .secondary

        case 0...2:
            return .red

        case 3...7:
            return .orange

        default:
            return .blue
        }
    }


    private func daysUntil(
        _ dueDate:
            Date
    ) -> Int {

        Calendar.current
            .dateComponents(
                [
                    .day
                ],
                from:
                    Calendar.current
                        .startOfDay(
                            for:
                                Date()
                        ),
                to:
                    Calendar.current
                        .startOfDay(
                            for:
                                dueDate
                        )
            )
            .day
        ??
        0
    }
}
