import Foundation

enum AppAuthConfiguration {

    static let urlScheme =
        "aidocbill"


    // Password Recovery

    static let passwordRecoveryRedirectURL =
        URL(
            string:
                "\(urlScheme)://reset-password"
        )!

    static func isPasswordRecoveryURL(
        _ url: URL
    ) -> Bool {

        url.scheme?.lowercased()
            == urlScheme
        &&
        url.host?.lowercased()
            == "reset-password"
    }


    // New Account Activation

    static let accountActivationRedirectURL =
        URL(
            string:
                "\(urlScheme)://account-activated"
        )!

    static func isAccountActivationURL(
        _ url: URL
    ) -> Bool {

        url.scheme?.lowercased()
            == urlScheme
        &&
        url.host?.lowercased()
            == "account-activated"
    }


    static func accountActivationError(
        _ url: URL
    ) -> String? {

        let parameters =
            authParameters(
                from:
                    url
            )


        guard
            let error =
                parameters[
                    "error_description"
                ]
                ??
                parameters[
                    "error"
                ],
            !error.isEmpty
        else {

            return nil
        }


        return
            error
                .replacingOccurrences(
                    of:
                        "+",
                    with:
                        " "
                )
    }


    // Secure Email Change

    static let emailChangeRedirectURL =
        URL(
            string:
                "\(urlScheme)://email-change"
        )!

    static func isEmailChangeURL(
        _ url: URL
    ) -> Bool {

        url.scheme?.lowercased()
            == urlScheme
        &&
        url.host?.lowercased()
            == "email-change"
    }


    enum EmailChangeCallbackKind:
        Equatable {

        case firstConfirmation

        case completion

        case failure(
            message: String
        )

        case unknown
    }


    static func emailChangeCallbackKind(
        _ url: URL
    ) -> EmailChangeCallbackKind {

        let parameters =
            authParameters(
                from: url
            )

        if let error =
            parameters[
                "error_description"
            ]
            ??
            parameters[
                "error"
            ],
           !error.isEmpty {

            return
                .failure(
                    message:
                        error
                            .replacingOccurrences(
                                of: "+",
                                with: " "
                            )
                )
        }


        if let code =
            parameters[
                "code"
            ],
           !code.isEmpty {

            return
                .completion
        }


        // This URL host is dedicated to Secure Email Change.
        // With Swift's default PKCE flow, the final confirmation
        // carries an auth `code`. The first accepted confirmation
        // redirects here without that final code.
        //
        // We Intentionally should NOT depend on Supabase's human-readable
        // `message` text, because that wording is not a stable API.
        return
            .firstConfirmation
    }


    // Auth URL Parameters

    private static func authParameters(
        from url: URL
    ) -> [String: String] {

        var result:
            [String: String] = [:]


        if let components =
            URLComponents(
                url: url,
                resolvingAgainstBaseURL:
                    false
            ) {

            for item
                in components
                    .queryItems
                    ?? [] {

                if let value =
                    item.value {

                    result[
                        item.name
                    ] =
                        value
                }
            }
        }


        // Some Supabase Auth flows may place values in the
        // URL fragment instead of the normal query string.
        if let fragment =
            url.fragment,
           !fragment.isEmpty,
           let fragmentComponents =
            URLComponents(
                string:
                    "https://callback.invalid/?\(fragment)"
            ) {

            for item
                in fragmentComponents
                    .queryItems
                    ?? [] {

                if let value =
                    item.value {

                    result[
                        item.name
                    ] =
                        value
                }
            }
        }


        return result
    }
}
