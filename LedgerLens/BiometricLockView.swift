import SwiftUI

struct BiometricLockView: View {

    @ObservedObject private var appLock =
        BiometricLockManager.shared

    var body: some View {

        ZStack {

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.10),
                    Color.clear,
                    Color.indigo.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {

                ZStack {

                    Circle()
                        .fill(
                            Color.blue.opacity(0.10)
                        )
                        .frame(
                            width: 112,
                            height: 112
                        )

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .blue,
                                    .indigo
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(
                            width: 88,
                            height: 88
                        )

                    Image(
                        systemName:
                            biometricSymbol
                    )
                    .font(
                        .system(
                            size: 39,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                }

                VStack(spacing: 8) {

                    Text(
                        "Financial documents locked"
                    )
                    .font(
                        .title2
                        .weight(.bold)
                    )

                    Text(
                        "Authenticate to access your document history and AI analysis."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                if let error =
                    appLock.lastErrorMessage {

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {

                    Task {

                        await appLock
                            .unlockIfNeeded()
                    }

                } label: {

                    HStack(spacing: 10) {

                        if appLock
                            .isAuthenticating {

                            ProgressView()
                                .tint(.white)

                        } else {

                            Image(
                                systemName:
                                    biometricSymbol
                            )
                        }

                        Text(
                            appLock
                                .isAuthenticating
                            ? "Authenticating…"
                            : "Unlock with \(appLock.biometryName)"
                        )
                        .font(.headline)
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [
                                .blue,
                                .indigo
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                }
                .disabled(
                    appLock
                        .isAuthenticating
                )
                .frame(
                    maxWidth: 420
                )
            }
            .padding(28)
        }
    }

    private var biometricSymbol:
        String {

        switch appLock.biometryName {

        case "Face ID":
            return "faceid"

        case "Touch ID":
            return "touchid"

        default:
            return "lock.shield.fill"
        }
    }
}
