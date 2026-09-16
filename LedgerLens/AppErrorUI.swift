import SwiftUI
import Foundation

enum AppOperationContext {
    case documentProcessing
    case question
    case history
    case download
    case account
}

enum AppFriendlyError {

    static func message(
        for error: Error,
        context: AppOperationContext,
        isConnected: Bool
    ) -> String {

        if !isConnected {

            switch context {

            case .documentProcessing:
                return "You're offline. Connect to the internet before uploading or scanning a document."

            case .question:
                return "You're offline. Reconnect before asking AI questions about this document."

            case .history:
                return "You're offline. Reconnect to refresh your document history."

            case .download:
                return "You're offline. Reconnect before downloading the saved original."

            case .account:
                return "You're offline. Reconnect before changing account settings."
            }
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {

            switch nsError.code {

            case NSURLErrorTimedOut:
                return "The request took too long. Your connection may be slow. Please try again."

            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                return "The network connection was interrupted. Reconnect and try again."

            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost:
                return "The service couldn't be reached. Please try again in a moment."

            default:
                break
            }
        }

        let lower =
            error.localizedDescription
                .lowercased()

        if lower.contains("429")
            || lower.contains("rate limit") {

            return "You've reached the temporary usage limit. Please wait a little while and try again."
        }

        if lower.contains("401")
            || lower.contains("authenticated user required")
            || lower.contains("jwt") {

            return "Your session may have expired. Sign out, sign back in, and try again."
        }

        if lower.contains("storage")
            || lower.contains("object not found") {

            return "The saved file couldn't be retrieved. Refresh History and try again."
        }

        switch context {

        case .documentProcessing:
            return "We couldn't analyze this document. Check your connection and try again."

        case .question:
            return "We couldn't answer that question right now. Please try again."

        case .history:
            return "We couldn't load your document history. Please try again."

        case .download:
            return "We couldn't prepare the saved original. Please try again."

        case .account:
            return "We couldn't complete that account request. Please try again."
        }
    }
}

struct OfflineBanner: View {

    let message: String

    init(
        message: String =
            "You're offline. Some features require an internet connection."
    ) {
        self.message = message
    }

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 11
        ) {

            Image(systemName: "wifi.slash")
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.orange)
                .padding(.top, 1)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("Offline")
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer()
        }
        .padding(14)
        .background(
            Color.orange.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                Color.orange.opacity(0.16)
            )
        }
    }
}

struct AppErrorCard: View {

    let title: String
    let message: String

    var retryTitle: String?
    var retry: (() -> Void)?

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(
                alignment: .top,
                spacing: 11
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.red.opacity(0.10)
                        )
                        .frame(
                            width: 38,
                            height: 38
                        )

                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.red)
                }

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(title)
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }

            if let retryTitle,
               let retry {

                Button(retryTitle) {
                    retry()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(15)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.red.opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.red.opacity(0.12)
            )
        }
    }
}
