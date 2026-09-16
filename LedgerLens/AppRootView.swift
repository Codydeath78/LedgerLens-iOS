import SwiftUI

struct AppRootView: View {

    @Environment(\.scenePhase)
    private var scenePhase

    @StateObject private var session =
        AppSessionController()

    @StateObject private var appLock =
        BiometricLockManager.shared

    var body: some View {

        ZStack {

            Group {

                switch session.phase {

                case .loading:

                    LaunchLoadingView()
                        .transition(.opacity)

                case .signedOut:

                    AuthLandingView()
                        .transition(
                            .opacity
                            .combined(
                                with:
                                    .scale(
                                        scale: 0.98
                                    )
                            )
                        )

                case .signedIn:

                    MainTabView()
                        .transition(.opacity)
                }
            }

            if session.phase ==
                .signedIn,
               appLock.isEnabled,
               appLock.isLocked {

                BiometricLockView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .environmentObject(session)
        .animation(
            .easeInOut(
                duration: 0.28
            ),
            value:
                session.phase
        )
        .animation(
            .easeInOut(
                duration: 0.20
            ),
            value:
                appLock.isLocked
        )
        .task {

            await session
                .restoreSessionIfNeeded()
        }
        .onOpenURL { url in

            Task {

                await session
                    .handleIncomingAuthURL(
                        url
                    )
            }
        }
        .alert(
            "Account activation",
            isPresented:
                $session
                    .isAccountActivationNoticePresented
        ) {

            Button(
                "OK"
            ) {

                session
                    .dismissAccountActivationNotice()
            }

        } message: {

            Text(
                session
                    .accountActivationNoticeMessage
                ??
                "Account activated. You can login!"
            )
        }
        .fullScreenCover(
            isPresented:
                $session
                    .isPasswordRecoveryPresented
        ) {

            ResetPasswordView()
                .environmentObject(session)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            isPresented:
                $session
                    .isEmailChangeConfirmationPresented
        ) {

            EmailChangeConfirmationView()
                .environmentObject(session)
                .interactiveDismissDisabled(
                    session
                        .emailChangeConfirmationStage
                    == .finishing
                )
        }
        .onChange(
            of: scenePhase
        ) {
            _, newPhase in

            switch newPhase {

            case .background:

                appLock.lock()

            case .active:

                if session.phase ==
                    .signedIn {

                    Task {

                        await appLock
                            .unlockIfNeeded()
                    }
                }

            default:

                break
            }
        }
        .onChange(
            of: session.phase
        ) {
            _, newPhase in

            guard newPhase ==
                .signedIn
            else {
                return
            }

            if appLock.isEnabled {

                appLock.lock()

                Task {

                    await appLock
                        .unlockIfNeeded()
                }
            }
        }
    }
}


private struct LaunchLoadingView: View {

    @State private var rotate =
        false

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.08),
                    Color.indigo.opacity(0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {

                ZStack {

                    Circle()
                        .stroke(
                            Color.blue.opacity(0.12),
                            lineWidth: 7
                        )
                        .frame(
                            width: 74,
                            height: 74
                        )

                    Circle()
                        .trim(
                            from: 0.08,
                            to: 0.70
                        )
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .blue,
                                    .indigo,
                                    .purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style:
                                StrokeStyle(
                                    lineWidth: 7,
                                    lineCap: .round
                                )
                        )
                        .frame(
                            width: 74,
                            height: 74
                        )
                        .rotationEffect(
                            .degrees(
                                rotate
                                ? 360
                                : 0
                            )
                        )

                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.blue)
                }

                Text(
                    "Getting things ready…"
                )
                .font(.headline)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {

            withAnimation(
                .linear(duration: 1.0)
                .repeatForever(
                    autoreverses: false
                )
            ) {

                rotate = true
            }
        }
    }
}


#Preview {
    AppRootView()
}
