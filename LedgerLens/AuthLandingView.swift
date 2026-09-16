import SwiftUI

struct AuthLandingView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @State private var developerLoading = false
    @State private var errorMessage: String?

    var body: some View {

        NavigationStack {

            ZStack {

                AuthBackground()

                ScrollView {

                    VStack(spacing: 28) {

                        Spacer(minLength: 38)

                        authHero

                        VStack(spacing: 13) {

                            NavigationLink {
                                LoginView()
                            } label: {
                                AuthPrimaryButtonLabel(
                                    title: "Log In",
                                    subtitle:
                                        "Continue to your saved documents",
                                    systemImage:
                                        "arrow.right.circle.fill"
                                )
                            }
                            .buttonStyle(
                                AuthPressButtonStyle()
                            )

                            NavigationLink {
                                SignUpView()
                            } label: {
                                AuthSecondaryButtonLabel(
                                    title: "Create Account",
                                    subtitle:
                                        "Save statements and bills securely",
                                    systemImage:
                                        "person.badge.plus"
                                )
                            }
                            .buttonStyle(
                                AuthPressButtonStyle()
                            )
                        }

                        privacyNote

                        #if DEBUG

                        developerSection

                        #endif

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 22)
                    .frame(
                        maxWidth: 560
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
            .alert(
                "Developer Sign-In Failed",
                isPresented: Binding(
                    get: {
                        errorMessage != nil
                    },
                    set: { newValue in
                        if !newValue {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(
                    errorMessage ?? ""
                )
            }
        }
    }

    private var authHero: some View {

        VStack(spacing: 18) {

            ZStack {

                Circle()
                    .fill(
                        Color.blue.opacity(0.10)
                    )
                    .frame(
                        width: 96,
                        height: 96
                    )

                Circle()
                    .fill(
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
                    .frame(
                        width: 78,
                        height: 78
                    )

                Image(
                    systemName:
                        "doc.text.magnifyingglass"
                )
                .font(
                    .system(
                        size: 31,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
            }

            VStack(spacing: 8) {

                Text(
                    "AI Document &\nBill Explainer"
                )
                .font(
                    .system(
                        size: 35,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .multilineTextAlignment(
                    .center
                )
                .tracking(-0.7)

                Text(
                    "Understand statements and bills, ask questions in plain English, and return to your previous documents anytime."
                )
                .font(
                    .system(
                        size: 16,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .lineSpacing(3)
            }
        }
    }

    private var privacyNote: some View {

        HStack(
            alignment: .top,
            spacing: 10
        ) {

            Image(
                systemName:
                    "lock.shield.fill"
            )
            .foregroundStyle(.green)

            Text(
                "Your document history is connected to your account and protected by Supabase authentication and database access rules."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(15)
        .background(
            Color.green.opacity(0.06)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    #if DEBUG

    private var developerSection: some View {

        VStack(spacing: 12) {

            HStack {

                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(0.18)
                    )
                    .frame(height: 1)

                Text("DEVELOPER")
                    .font(
                        .caption2
                        .weight(.bold)
                    )
                    .foregroundStyle(
                        .secondary
                    )

                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(0.18)
                    )
                    .frame(height: 1)
            }

            Button {

                developerLoading = true

                Task {

                    do {

                        try await session
                            .developerSkip()

                    } catch {

                        errorMessage =
                            error.localizedDescription
                    }

                    developerLoading = false
                }

            } label: {

                HStack(spacing: 10) {

                    if developerLoading {

                        ProgressView()

                    } else {

                        Image(
                            systemName:
                                "hammer.fill"
                        )
                    }

                    Text(
                        developerLoading
                        ? "Starting developer session…"
                        : "Skip Login for Development"
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding(.vertical, 14)
                .background(
                    Color.orange
                        .opacity(0.10)
                )
                .foregroundStyle(
                    .orange
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
                        Color.orange
                            .opacity(0.18)
                    )
                }
            }
            .buttonStyle(
                AuthPressButtonStyle()
            )
            .disabled(
                developerLoading
            )

            Text(
                "DEBUG builds only. This button is not compiled into Release builds."
            )
            .font(.caption2)
            .foregroundStyle(
                .tertiary
            )
            .multilineTextAlignment(
                .center
            )
        }
    }

    #endif
}

// Shared Auth UI

struct AuthBackground: View {

    var body: some View {

        ZStack {

            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.065),
                    Color.clear,
                    Color.indigo.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    Color.blue.opacity(0.06)
                )
                .frame(
                    width: 310,
                    height: 310
                )
                .blur(radius: 50)
                .offset(
                    x: 170,
                    y: -310
                )

            Circle()
                .fill(
                    Color.indigo.opacity(0.05)
                )
                .frame(
                    width: 250,
                    height: 250
                )
                .blur(radius: 55)
                .offset(
                    x: -170,
                    y: 360
                )
        }
    }
}

struct AuthPrimaryButtonLabel: View {

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {

        HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(0.17)
                )
                .frame(
                    width: 48,
                    height: 48
                )

                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .opacity(0.78)
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
        }
        .padding(16)
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
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color:
                Color.blue.opacity(0.20),
            radius: 17,
            y: 7
        )
    }
}

struct AuthSecondaryButtonLabel: View {

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {

        HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .fill(
                    Color.blue.opacity(0.10)
                )
                .frame(
                    width: 48,
                    height: 48
                )

                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.blue)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(.headline)
                    .foregroundStyle(
                        .primary
                    )

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.09)
            )
        }
    }
}

struct AuthPressButtonStyle:
    ButtonStyle {

    func makeBody(
        configuration: Configuration
    ) -> some View {

        configuration.label
            .scaleEffect(
                configuration.isPressed
                ? 0.975
                : 1
            )
            .opacity(
                configuration.isPressed
                ? 0.91
                : 1
            )
            .animation(
                .spring(
                    response: 0.28,
                    dampingFraction: 0.72
                ),
                value:
                    configuration.isPressed
            )
    }
}
