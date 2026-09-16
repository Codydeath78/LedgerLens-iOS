import SwiftUI

struct ResetPasswordView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var didSave = false
    @State private var errorMessage: String?

    var body: some View {

        NavigationStack {

            ZStack {

                AuthBackground()

                if didSave {

                    successView

                } else if
                    !session
                        .isPasswordRecoveryReady {

                    preparingView

                } else {

                    form
                }
            }
            .navigationTitle("")
            .toolbar(
                .hidden,
                for:
                    .navigationBar
            )
        }
    }

    private var preparingView:
        some View {

        VStack(spacing: 18) {

            ProgressView()
                .controlSize(
                    .large
                )

            Text(
                "Preparing secure password reset…"
            )
            .font(
                .headline
            )

            if let message =
                session.authLinkError {

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(
                        .red
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .padding(.horizontal)
            }
        }
        .padding(28)
    }

    private var form:
        some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 23
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text(
                        "Choose a new password"
                    )
                    .font(
                        .system(
                            size: 33,
                            weight: .bold,
                            design: .rounded
                        )
                    )

                    Text(
                        "Create a new password for your AI Document & Bill Explainer account."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                }

                SecureField(
                    "New password",
                    text:
                        $password
                )
                .textContentType(
                    .newPassword
                )
                .padding(16)
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )

                SecureField(
                    "Confirm new password",
                    text:
                        $confirmPassword
                )
                .textContentType(
                    .newPassword
                )
                .padding(16)
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {

                    requirement(
                        title:
                            "At least 6 characters",
                        met:
                            password.count >= 6
                    )

                    requirement(
                        title:
                            "Passwords match",
                        met:
                            passwordsMatch
                    )
                }

                if let errorMessage {

                    Label(
                        errorMessage,
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(14)
                    .background(
                        Color.red.opacity(0.07)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                    )
                }

                Button {

                    save()

                } label: {

                    HStack(spacing: 10) {

                        if isSaving {

                            ProgressView()
                                .tint(.white)
                        }

                        Text(
                            isSaving
                            ? "Updating password…"
                            : "Update Password"
                        )
                        .font(.headline)
                    }
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        16
                    )
                    .foregroundStyle(
                        .white
                    )
                    .background(
                        LinearGradient(
                            colors: [
                                .blue,
                                .indigo
                            ],
                            startPoint:
                                .topLeading,
                            endPoint:
                                .bottomTrailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 19,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(
                    AuthPressButtonStyle()
                )
                .disabled(
                    !canSubmit ||
                    isSaving
                )
                .opacity(
                    canSubmit ? 1 : 0.55
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 38)
            .padding(.bottom, 44)
            .frame(maxWidth: 560)
            .frame(
                maxWidth: .infinity
            )
        }
    }

    private var successView:
        some View {

        VStack(spacing: 21) {

            ZStack {

                Circle()
                    .fill(
                        Color.green
                            .opacity(0.11)
                    )
                    .frame(
                        width: 100,
                        height: 100
                    )

                Image(
                    systemName:
                        "checkmark.shield.fill"
                )
                .font(
                    .system(
                        size: 43
                    )
                )
                .foregroundStyle(
                    .green
                )
            }

            Text(
                "Password updated"
            )
            .font(
                .title
                .weight(.bold)
            )

            Text(
                "Your new password is ready to use."
            )
            .foregroundStyle(
                .secondary
            )

            Button {

                session
                    .finishPasswordRecovery()

            } label: {

                Text("Continue")
                    .font(.headline)
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        16
                    )
                    .foregroundStyle(
                        .white
                    )
                    .background(
                        LinearGradient(
                            colors: [
                                .blue,
                                .indigo
                            ],
                            startPoint:
                                .topLeading,
                            endPoint:
                                .bottomTrailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 19,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(
                AuthPressButtonStyle()
            )
        }
        .padding(28)
        .frame(maxWidth: 560)
    }

    private var passwordsMatch:
        Bool {

        !password.isEmpty
        &&
        password ==
            confirmPassword
    }

    private var canSubmit:
        Bool {

        password.count >= 6
        &&
        passwordsMatch
    }

    private func requirement(
        title: String,
        met: Bool
    ) -> some View {

        Label(
            title,
            systemImage:
                met
                ? "checkmark.circle.fill"
                : "circle"
        )
        .font(.caption)
        .foregroundStyle(
            met
            ? .green
            : .secondary
        )
    }

    private func save() {

        guard
            canSubmit,
            !isSaving
        else {
            return
        }

        isSaving =
            true

        errorMessage =
            nil

        Task {

            do {

                try await
                    SupabaseAuthManager
                        .shared
                        .updatePassword(
                            password
                        )

                didSave =
                    true

            } catch {

                errorMessage =
                    error.localizedDescription
            }

            isSaving =
                false
        }
    }
}
