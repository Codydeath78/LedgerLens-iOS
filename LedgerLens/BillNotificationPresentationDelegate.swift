// Shows bill-reminder banners even while the app is open.
// The singleton is retained for the lifetime of the process.

import Foundation
import UserNotifications


final class BillNotificationPresentationDelegate:
    NSObject,
    UNUserNotificationCenterDelegate,
    @unchecked Sendable {

    static let shared =
        BillNotificationPresentationDelegate()


    private override init() {

        super.init()
    }


    func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        willPresent notification:
            UNNotification,
        withCompletionHandler completionHandler:
            @escaping (
                UNNotificationPresentationOptions
            ) -> Void
    ) {

        completionHandler(
            [
                .banner,
                .list,
                .sound
            ]
        )
    }


    func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        didReceive response:
            UNNotificationResponse,
        withCompletionHandler completionHandler:
            @escaping () -> Void
    ) {

        // Tapping the reminder opens the app normally.
        // The document UUID is already included in userInfo for
        // a future direct-to-document routing enhancement.
        completionHandler()
    }
}
