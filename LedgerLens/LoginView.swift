import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField:
        Field?

    private enum Field {
        case email
        case password
    }

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
                        spacing: 8
                    ) {

                        Text("Welcome back")
                            .font(
                                .system(
                                    size: 34,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )

                        Text(
                            "Log in to analyze documents and access your saved history."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    VStack(spacing: 14) {

                        authTextField(
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

                        authTextField(
                            title: "Password",
                            systemImage:
                                "lock.fill"
                        ) {

                            HStack {

                                Group {

                                    if showPassword {

                                        TextField(
                                            "Password",
                                            text:
                                                $password
                                        )

                                    } else {

                                        SecureField(
                                            "Password",
                                            text:
                                                $password
                                        )
                                    }
                                }
                                .focused(
                                    $focusedField,
                                    equals:
                                        .password
                                )
                                .submitLabel(.go)
                                .onSubmit {
                                    submit()
                                }

                                Button {

                                    showPassword
                                        .toggle()

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

                    HStack {

                        Spacer()

                        NavigationLink {

                            ForgotPasswordView()

                        } label: {

                            Text(
                                "Forgot password?"
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )
                        }
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
                                ? "Logging in…"
                                : "Log In"
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
                        canSubmit ? 1 : 0.55
                    )

                    HStack {

                        Text("New here?")
                            .foregroundStyle(
                                .secondary
                            )

                        NavigationLink(
                            "Create Account"
                        ) {
                            SignUpView()
                        }
                        .fontWeight(
                            .semibold
                        )
                    }
                    .font(.subheadline)
                    .frame(
                        maxWidth: .infinity
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
            .scrollDismissesKeyboard(
                .interactively
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private var canSubmit:
        Bool {

        !email
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        &&
        !password.isEmpty
    }

    private func submit() {

        guard
            canSubmit,
            !isLoading
        else {
            return
        }

        errorMessage =
            nil

        focusedField =
            nil

        isLoading =
            true

        let cleanedEmail =
            email
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        Task {

            do {

                try await session
                    .signIn(
                        email:
                            cleanedEmail,
                        password:
                            password
                    )

            } catch {

                errorMessage =
                    error.localizedDescription
            }

            isLoading =
                false
        }
    }

    @ViewBuilder
    private func authTextField<
        Content: View
    >(
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
                .foregroundStyle(
                    .blue
                )
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
}
