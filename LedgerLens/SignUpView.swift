import SwiftUI

struct SignUpView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmationEmail: String?

    @FocusState private var focusedField:
        Field?

    private enum Field {
        case email
        case password
        case confirmPassword
    }

    var body: some View {

        ZStack {

            AuthBackground()

            if let confirmationEmail {

                confirmationView(
                    email:
                        confirmationEmail
                )

            } else {

                signUpForm
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private var signUpForm: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 23
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Create your account")
                        .font(
                            .system(
                                size: 34,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                    Text(
                        "Save document history and return to statements and bills you've analyzed before."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                }

                VStack(spacing: 14) {

                    authField(
                        title: "Email",
                        systemImage:
                            "envelope.fill"
                    ) {

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
                            $focusedField,
                            equals: .email
                        )
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField =
                                .password
                        }
                    }

                    authField(
                        title: "Password",
                        systemImage:
                            "lock.fill"
                    ) {

                        passwordField(
                            placeholder:
                                "At least 6 characters",
                            text:
                                $password,
                            focus:
                                .password
                        )
                    }

                    authField(
                        title: "Confirm Password",
                        systemImage:
                            "lock.rotation"
                    ) {

                        passwordField(
                            placeholder:
                                "Enter password again",
                            text:
                                $confirmPassword,
                            focus:
                                .confirmPassword
                        )
                    }
                }

                passwordRequirements

                if let errorMessage {

                    Label(
                        errorMessage,
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(14)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
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
                    submit()
                } label: {

                    HStack(spacing: 10) {

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(
                            isLoading
                            ? "Creating account…"
                            : "Create Account"
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
                    isLoading
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
            .frame(
                maxWidth: 560
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .scrollDismissesKeyboard(
            .interactively
        )
    }

    private var passwordRequirements:
        some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Label(
                "Use at least 6 characters",
                systemImage:
                    password.count >= 6
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .foregroundStyle(
                password.count >= 6
                ? .green
                : .secondary
            )

            Label(
                "Passwords match",
                systemImage:
                    passwordsMatch
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .foregroundStyle(
                passwordsMatch
                ? .green
                : .secondary
            )
        }
        .font(.caption)
    }

    private var passwordsMatch: Bool {

        !password.isEmpty &&
        password == confirmPassword
    }

    private var canSubmit: Bool {

        !email
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        &&
        password.count >= 6
        &&
        passwordsMatch
    }

    private func submit() {

        guard canSubmit,
              !isLoading
        else {
            return
        }

        errorMessage = nil
        focusedField = nil
        isLoading = true

        let cleanedEmail =
            email
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        Task {

            do {

                let result =
                    try await session
                        .signUp(
                            email:
                                cleanedEmail,
                            password:
                                password
                        )

                switch result {

                case .signedIn:
                    break

                case .confirmationRequired(
                    let email
                ):
                    confirmationEmail =
                        email
                }

            } catch {

                errorMessage =
                    error.localizedDescription
            }

            isLoading = false
        }
    }

    private func confirmationView(
        email: String
    ) -> some View {

        VStack(spacing: 21) {

            Spacer()

            ZStack {

                Circle()
                    .fill(
                        Color.green.opacity(0.11)
                    )
                    .frame(
                        width: 100,
                        height: 100
                    )

                Image(
                    systemName:
                        "envelope.badge.fill"
                )
                .font(
                    .system(
                        size: 40,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .green
                )
            }

            VStack(spacing: 8) {

                Text("Check your email")
                    .font(
                        .title
                        .weight(.bold)
                    )

                Text(
                    "We sent a verification link to \(email). Verify your address, then return to the app and log in."
                )
                .multilineTextAlignment(
                    .center
                )
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }

            NavigationLink {
                LoginView()
            } label: {

                Text(
                    "Go to Log In"
                )
                .font(.headline)
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

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(
            maxWidth: 560
        )
        .frame(
            maxWidth: .infinity
        )
    }

    @ViewBuilder
    private func authField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Text(title)
                .font(
                    .subheadline
                    .weight(.semibold)
                )

            HStack(spacing: 11) {

                Image(
                    systemName:
                        systemImage
                )
                .foregroundStyle(.blue)
                .frame(width: 22)

                content()
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 54)
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
            .overlay {

                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.08)
                )
            }
        }
    }

    @ViewBuilder
    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        focus: Field
    ) -> some View {

        HStack {

            Group {

                if showPassword {

                    TextField(
                        placeholder,
                        text: text
                    )

                } else {

                    SecureField(
                        placeholder,
                        text: text
                    )
                }
            }
            .focused(
                $focusedField,
                equals: focus
            )
            .submitLabel(
                focus == .confirmPassword
                ? .done
                : .next
            )
            .onSubmit {

                switch focus {

                case .password:
                    focusedField =
                        .confirmPassword

                case .confirmPassword:
                    submit()

                case .email:
                    focusedField =
                        .password
                }
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(
                    systemName:
                        showPassword
                        ? "eye.slash.fill"
                        : "eye.fill"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .buttonStyle(.plain)
        }
    }
}
