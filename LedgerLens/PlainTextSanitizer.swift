// Goal:
// Users should never see raw Markdown markers such as:
// **bold**
// _italic_
// `code`
// # headings
// > blockquotes
// [label](https://example.com)
// | markdown | tables |
// ``` code fences ```
//
// This is intentionally display/storage normalization,
// not a Markdown renderer.

import Foundation

enum PlainTextSanitizer {

    static func clean(
        _ input: String
    ) -> String {

        guard
            !input.isEmpty
        else {
            return input
        }

        var text =
            input
                .replacingOccurrences(
                    of: "\r\n",
                    with: "\n"
                )
                .replacingOccurrences(
                    of: "\r",
                    with: "\n"
                )


        // Code fences

        text =
            replacingRegex(
                pattern:
                    #"(?m)^\s*```[A-Za-z0-9_+\-]*\s*$"#,
                in:
                    text,
                with:
                    ""
            )


        // Images + links

        text =
            replacingRegex(
                pattern:
                    #"!\[([^\]]*)\]\([^)]+\)"#,
                in:
                    text,
                with:
                    "$1"
            )

        text =
            replacingRegex(
                pattern:
                    #"\[([^\]]+)\]\([^)]+\)"#,
                in:
                    text,
                with:
                    "$1"
            )

        text =
            replacingRegex(
                pattern:
                    #"<(https?://[^>]+)>"#,
                in:
                    text,
                with:
                    "$1"
            )


        // Bold / italic / strikethrough / inline code

        let inlinePatterns:
            [
                (
                    pattern: String,
                    replacement: String
                )
            ] = [

                (
                    #"\*\*([^*\n]+?)\*\*"#,
                    "$1"
                ),

                (
                    #"__([^_\n]+?)__"#,
                    "$1"
                ),

                (
                    #"~~([^~\n]+?)~~"#,
                    "$1"
                ),

                (
                    #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#,
                    "$1"
                ),

                (
                    #"(?<!_)_([^_\n]+?)_(?!_)"#,
                    "$1"
                ),

                (
                    #"`([^`\n]+?)`"#,
                    "$1"
                )
            ]

        for item
            in inlinePatterns {

            text =
                replacingRegex(
                    pattern:
                        item.pattern,
                    in:
                        text,
                    with:
                        item.replacement
                )
        }


        // Headings / blockquotes / horizontal rules

        text =
            replacingRegex(
                pattern:
                    #"(?m)^\s{0,3}#{1,6}\s+"#,
                in:
                    text,
                with:
                    ""
            )

        text =
            replacingRegex(
                pattern:
                    #"(?m)^\s{0,3}>\s?"#,
                in:
                    text,
                with:
                    ""
            )

        text =
            replacingRegex(
                pattern:
                    #"(?m)^\s*(?:[-*_]\s*){3,}$"#,
                in:
                    text,
                with:
                    ""
            )


        // Markdown bullets -> real bullets

        text =
            replacingRegex(
                pattern:
                    #"(?m)^\s*[-+*]\s+"#,
                in:
                    text,
                with:
                    "• "
            )


        // HTML breaks/tags

        text =
            replacingRegex(
                pattern:
                    #"(?i)<br\s*/?>"#,
                in:
                    text,
                with:
                    "\n"
            )

        text =
            replacingRegex(
                pattern:
                    #"<[^>]+>"#,
                in:
                    text,
                with:
                    ""
            )


        // Markdown table cleanup

        let cleanedLines =
            text
                .components(
                    separatedBy:
                        "\n"
                )
                .compactMap {
                    cleanLine(
                        $0
                    )
                }

        text =
            cleanedLines
                .joined(
                    separator:
                        "\n"
                )


        // Common escaped Markdown punctuation

        let escapedCharacters = [
            "\\*": "*",
            "\\_": "_",
            "\\#": "#",
            "\\`": "`",
            "\\[": "[",
            "\\]": "]",
            "\\(": "(",
            "\\)": ")",
            "\\>": ">",
            "\\+": "+",
            "\\-": "-",
            "\\.": ".",
            "\\!": "!"
        ]

        for (
            escaped,
            plain
        ) in escapedCharacters {

            text =
                text
                    .replacingOccurrences(
                        of:
                            escaped,
                        with:
                            plain
                    )
        }


        // Defensive leftover marker cleanup
        //
        // These specifically remove common unmatched formatting
        // pairs without touching normal punctuation such as
        // multiplication signs or underscores inside identifiers.

        text =
            text
                .replacingOccurrences(
                    of: "**",
                    with: ""
                )
                .replacingOccurrences(
                    of: "__",
                    with: ""
                )
                .replacingOccurrences(
                    of: "```",
                    with: ""
                )


        // Whitespace normalization

        text =
            replacingRegex(
                pattern:
                    #"[ \t]+\n"#,
                in:
                    text,
                with:
                    "\n"
            )

        text =
            replacingRegex(
                pattern:
                    #"\n{3,}"#,
                in:
                    text,
                with:
                    "\n\n"
            )

        return
            text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
    }


    // Line Cleanup

    private static func cleanLine(
        _ line: String
    ) -> String? {

        let trimmed =
            line
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        // Markdown table separator:
        // | --- | :---: | ---: |
        if isMarkdownTableSeparator(
            trimmed
        ) {

            return nil
        }


        // Convert a likely Markdown table row into readable
        // plain text without vertical bars.
        let pipeCount =
            trimmed
                .filter {
                    $0 == "|"
                }
                .count

        if pipeCount >= 2 {

            var row =
                trimmed

            if row
                .hasPrefix("|") {

                row.removeFirst()
            }

            if row
                .hasSuffix("|") {

                row.removeLast()
            }

            let cells =
                row
                    .split(
                        separator:
                            "|",
                        omittingEmptySubsequences:
                            false
                    )
                    .map {
                        clean(
                            String($0)
                        )
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                    }
                    .filter {
                        !$0.isEmpty
                    }

            if !cells.isEmpty {

                return
                    cells
                        .joined(
                            separator:
                                " • "
                        )
            }
        }


        return line
    }


    private static func isMarkdownTableSeparator(
        _ line: String
    ) -> Bool {

        guard
            line.contains("|")
        else {
            return false
        }

        let stripped =
            line
                .replacingOccurrences(
                    of: "|",
                    with: ""
                )
                .replacingOccurrences(
                    of: ":",
                    with: ""
                )
                .replacingOccurrences(
                    of: "-",
                    with: ""
                )
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: "\t",
                    with: ""
                )

        return
            stripped.isEmpty
            &&
            line.contains("-")
    }


    // Regex

    private static func replacingRegex(
        pattern: String,
        in source: String,
        with replacement: String
    ) -> String {

        guard
            let regex =
                try? NSRegularExpression(
                    pattern:
                        pattern,
                    options:
                        []
                )
        else {

            return source
        }

        let range =
            NSRange(
                source.startIndex...,
                in: source
            )

        return
            regex
                .stringByReplacingMatches(
                    in:
                        source,
                    options:
                        [],
                    range:
                        range,
                    withTemplate:
                        replacement
                )
    }
}


extension String {

    var aiPlainText:
        String {

        PlainTextSanitizer
            .clean(
                self
            )
    }
}
