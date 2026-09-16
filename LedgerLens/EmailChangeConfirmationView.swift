import SwiftUI

struct EmailChangeConfirmationView: View {

    @EnvironmentObject private var session:
        AppSessionController

    var body: some View {

        NavigationStack {

            ZStack {

                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.06),
                        Color.indigo.opacity(0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {

                    VStack(spacing: 24) {

                        statusIcon

                        statusCopy

                        emailDetails

                        actionButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }


    // Status Icon

    @ViewBuilder
    private var statusIcon: some View {

        switch session.emailChangeConfirmationStage {

        case .firstConfirmed:

            confirmationCircle(
                systemImage: "envelope.badge.fill",
                tint: .blue
            )

        case .finishing:

            ZStack {

                Circle()
                    .fill(
                        Color.blue.opacity(0.10)
                    )
                    .frame(width: 112, height: 112)

                ProgressView()
                    .controlSize(.large)
            }

        case .completed:

            confirmationCircle(
                systemImage: "checkmark.shield.fill",
                tint: .green
            )

        case .failed:

            confirmationCircle(
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )

        case .none:

            confirmationCircle(
                systemImage: "envelope.fill",
                tint: .blue
            )
        }
    }


    private func confirmationCircle(
        systemImage: String,
        tint: Color
    ) -> some View {

        ZStack {

            Circle()
                .fill(
                    tint.opacity(0.10)
                )
                .frame(width: 112, height: 112)

            Circle()
                .fill(
                    tint.opacity(0.13)
                )
                .frame(width: 82, height: 82)

            Image(
                systemName: systemImage
            )
            .font(
                .system(
                    size: 35,
                    weight: .semibold
                )
            )
            .foregroundStyle(tint)
        }
    }


    // Status Copy

    @ViewBuilder
    private var statusCopy: some View {

        switch session.emailChangeConfirmationStage {

        case .firstConfirmed:

            VStack(spacing: 10) {

                Text("1 of 2 email confirmations complete")
                    .font(
                        .system(
                            size: 28,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .multilineTextAlignment(.center)

                Text(
                    "One email address has been confirmed. For security, confirm the link in the other inbox before the email change becomes active."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }

        case .finishing:

            VStack(spacing: 10) {

                Text("Finishing email change…")
                    .font(
                        .title2
                        .weight(.bold)
                    )

                Text(
                    "Both confirmations were received. Updating your account now."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

        case .completed(
            let email
        ):

            VStack(spacing: 10) {

                Text("Email updated")
                    .font(
                        .system(
                            size: 30,
                            weight: .bold,
                            design: .rounded
                        )
                    )

                Text(
                    "Both confirmations are complete. Your sign-in email is now:"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Text(email)
                    .font(
                        .headline
                    )
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }

        case .failed(
            let message
        ):

            VStack(spacing: 10) {

                Text("Email confirmation failed")
                    .font(
                        .title2
                        .weight(.bold)
                    )

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

        case .none:

            Text("Email confirmation")
                .font(.title2.weight(.bold))
        }
    }


    // Email Details

    @ViewBuilder
    private var emailDetails: some View {

        if session.emailChangeConfirmationStage
            == .firstConfirmed {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                Label(
                    "Secure Email Change",
                    systemImage: "lock.shield.fill"
                )
                .font(.headline)

                if let oldEmail =
                    session.pendingEmailChangeOldEmail {

                    emailRow(
                        title: "Current email",
                        value: oldEmail
                    )
                }

                if let newEmail =
                    session.pendingEmailChangeNewEmail {

                    emailRow(
                        title: "New email",
                        value: newEmail
                    )
                }

                Text(
                    "Supabase allows either confirmation link to be clicked first, so the app does not guess which inbox you just confirmed. Once the second link is confirmed, your new email becomes active immediately."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .padding(16)
            .background(
                Color.blue.opacity(0.055)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
    }


    private func emailRow(
        title: String,
        value: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            Text(title)
                .font(
                    .caption
                    .weight(.semibold)
                )
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }


    // Action

    @ViewBuilder
    private var actionButton: some View {

        switch session.emailChangeConfirmationStage {

        case .finishing:

            EmptyView()

        case .completed:

            Button {

                session
                    .dismissEmailChangeConfirmation()

            } label: {

                Text("Back to Account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
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
                            cornerRadius: 19,
                            style: .continuous
                        )
                    )
            }

        case .firstConfirmed:

            Button {

                session
                    .dismissEmailChangeConfirmation()

            } label: {

                Text("I'll Confirm the Other Email")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

        case .failed:

            Button {

                session
                    .dismissEmailChangeConfirmation()

            } label: {

                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

        case .none:

            Button("Close") {

                session
                    .dismissEmailChangeConfirmation()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
