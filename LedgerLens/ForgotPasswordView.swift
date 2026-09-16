import SwiftUI

struct ForgotPasswordView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @State private var email = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    @FocusState private var emailFocused:
        Bool

    var body: some View {

        ZStack {

            AuthBackground()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    VStack(
                        alignment: .leading,
                        spacing: 9
                    ) {

                        Text(
                            "Reset your password"
                        )
                        .font(
                            .system(
                                size: 33,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                        Text(
                            "Enter your email and we'll send you a secure link that opens this app so you can choose a new password."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .secondary
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {

                        Text("Email")
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )

                        HStack(spacing: 11) {

                            Image(
                                systemName:
                                    "envelope.fill"
                            )
                            .foregroundStyle(
                                .blue
                            )
                            .frame(width: 22)

                            TextField(
                                "you@example.com",
                                text: $email
                            )
                            .textInputAutocapitalization(
                                .never
                            )
                            .keyboardType(
                                .emailAddress
                            )
                            .autocorrectionDisabled()
                            .focused(
                                $emailFocused
                            )
                            .submitLabel(.send)
                            .onSubmit {
                                send()
                            }
                        }
                        .padding(
                            .horizontal,
                            15
                        )
                        .frame(
                            minHeight: 54
                        )
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
                    }

                    if didSend {

                        Label(
                            "If an account exists for that email, a password reset link has been sent. Check your inbox and spam folder.",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .green
                        )
                        .padding(15)
                        .background(
                            Color.green
                                .opacity(0.07)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
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
                        .padding(15)
                        .background(
                            Color.red
                                .opacity(0.07)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }

                    Button {

                        send()

                    } label: {

                        HStack(spacing: 10) {

                            if isSending {

                                ProgressView()
                                    .tint(.white)
                            }

                            Text(
                                isSending
                                ? "Sending reset link…"
                                : "Send Reset Link"
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
                        isSending
                    )
                    .opacity(
                        canSubmit
                        ? 1
                        : 0.55
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 44)
                .frame(maxWidth: 560)
                .frame(
                    maxWidth: .infinity
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .onAppear {

            emailFocused =
                true
        }
    }

    private var canSubmit:
        Bool {

        !email
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    private func send() {

        guard
            canSubmit,
            !isSending
        else {
            return
        }

        emailFocused =
            false

        errorMessage =
            nil

        didSend =
            false

        isSending =
            true

        let cleanEmail =
            email
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        Task {

            do {

                try await session
                    .sendPasswordReset(
                        email:
                            cleanEmail
                    )

                didSend =
                    true

            } catch {

                errorMessage =
                    error.localizedDescription
            }

            isSending =
                false
        }
    }
}
