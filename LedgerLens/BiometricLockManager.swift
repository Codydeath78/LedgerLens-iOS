import Foundation
import LocalAuthentication
internal import Combine

@MainActor
final class BiometricLockManager: ObservableObject {

    static let shared =
        BiometricLockManager()

    @Published private(set)
    var isEnabled: Bool

    @Published private(set)
    var isLocked: Bool

    @Published private(set)
    var isAuthenticating =
        false

    @Published private(set)
    var biometryName =
        "Biometrics"

    @Published private(set)
    var isBiometryAvailable =
        false

    @Published
    var lastErrorMessage:
        String?

    private let enabledKey =
        "ai_document_biometric_lock_enabled"

    private init() {

        let enabled =
            UserDefaults.standard
                .bool(
                    forKey:
                        enabledKey
                )

        isEnabled =
            enabled

        isLocked =
            enabled

        refreshAvailability()
    }


    // Availability

    func refreshAvailability() {

        let context =
            LAContext()

        var error:
            NSError?

        isBiometryAvailable =
            context.canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: &error
            )

        switch context.biometryType {

        case .faceID:

            biometryName =
                "Face ID"

        case .touchID:

            biometryName =
                "Touch ID"

        case .none:

            biometryName =
                "Biometrics"

        @unknown default:

            biometryName =
                "Biometrics"
        }
    }


    // Enable / Disable

    func enableProtection()
        async -> Bool {

        refreshAvailability()

        guard
            isBiometryAvailable
        else {

            lastErrorMessage =
                """
                Face ID or Touch ID isn't available or enrolled on this device.
                """

            return false
        }

        do {

            let success =
                try await evaluate(
                    policy:
                        .deviceOwnerAuthenticationWithBiometrics,
                    reason:
                        "Protect your financial documents."
                )

            guard success else {
                return false
            }

            UserDefaults.standard
                .set(
                    true,
                    forKey:
                        enabledKey
                )

            isEnabled =
                true

            isLocked =
                false

            lastErrorMessage =
                nil

            return true

        } catch {

            lastErrorMessage =
                error.localizedDescription

            return false
        }
    }


    func disableProtection() {

        UserDefaults.standard
            .set(
                false,
                forKey:
                    enabledKey
            )

        isEnabled =
            false

        isLocked =
            false

        lastErrorMessage =
            nil
    }


    // Lock / Unlock

    func lock() {

        guard isEnabled else {
            return
        }

        isLocked =
            true
    }


    func unlockIfNeeded()
        async {

        guard
            isEnabled,
            isLocked,
            !isAuthenticating
        else {
            return
        }

        isAuthenticating =
            true

        lastErrorMessage =
            nil

        defer {

            isAuthenticating =
                false
        }

        do {

            // This policy uses biometrics first and lets iOS
            // offer the device passcode as a fallback.
            let success =
                try await evaluate(
                    policy:
                        .deviceOwnerAuthentication,
                    reason:
                        "Unlock your financial documents."
                )

            if success {

                isLocked =
                    false

                lastErrorMessage =
                    nil
            }

        } catch {

            let nsError =
                error as NSError

            // Cancel is normal. Keep the app locked without
            // turning it into a scary error state.
            if nsError.domain ==
                LAError.errorDomain,
               nsError.code ==
                LAError.userCancel
                    .rawValue {

                return
            }

            lastErrorMessage =
                error.localizedDescription
        }
    }


    // Evaluation

    private func evaluate(
        policy: LAPolicy,
        reason: String
    ) async throws -> Bool {

        let context =
            LAContext()

        context.localizedCancelTitle =
            "Cancel"

        return try await
            withCheckedThrowingContinuation {
                continuation in

                context.evaluatePolicy(
                    policy,
                    localizedReason:
                        reason
                ) {
                    success,
                    error in

                    if let error {

                        continuation
                            .resume(
                                throwing:
                                    error
                            )

                    } else {

                        continuation
                            .resume(
                                returning:
                                    success
                            )
                    }
                }
            }
    }
}
