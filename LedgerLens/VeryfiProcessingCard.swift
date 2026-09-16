import SwiftUI
import Foundation

struct VeryfiProcessingCard: View {

    @State private var messageIndex =
        0

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    private let messages = [
        "Sending your document securely…",
        "Reading financial details…",
        "Organizing transactions and charges…",
        "Preparing your AI workspace…"
    ]

    var body: some View {

        VStack(spacing: 22) {

            VeryfiProcessingAnimation(
                reduceMotion:
                    reduceMotion
            )

            VStack(spacing: 7) {

                Text(
                    "Analyzing document"
                )
                .font(
                    .title3
                    .weight(.bold)
                )

                Text(
                    messages[
                        messageIndex
                    ]
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .contentTransition(
                    .opacity
                )
                .id(messageIndex)
            }

            HStack(spacing: 6) {

                ForEach(
                    0..<messages.count,
                    id: \.self
                ) {
                    index in

                    Capsule()
                        .fill(
                            index ==
                                messageIndex
                            ? Color.blue
                            : Color.secondary
                                .opacity(0.18)
                        )
                        .frame(
                            width:
                                index ==
                                    messageIndex
                                ? 25
                                : 7,
                            height: 7
                        )
                        .animation(
                            .spring(
                                response:
                                    0.30
                            ),
                            value:
                                messageIndex
                        )
                }
            }

            Label(
                "Secure backend processing",
                systemImage:
                    "lock.shield.fill"
            )
            .font(.caption)
            .foregroundStyle(
                .tertiary
            )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
            .stroke(
                Color.blue
                    .opacity(0.10),
                lineWidth: 1
            )
        }
        .task {

            guard
                !reduceMotion
            else {
                return
            }

            while !Task.isCancelled {

                try? await Task.sleep(
                    for:
                        .seconds(1.45)
                )

                guard
                    !Task.isCancelled
                else {
                    return
                }

                withAnimation(
                    .easeInOut(
                        duration: 0.28
                    )
                ) {

                    messageIndex =
                        (
                            messageIndex
                            + 1
                        )
                        % messages.count
                }
            }
        }
    }
}


private struct VeryfiProcessingAnimation:
    View {

    let reduceMotion:
        Bool

    var body: some View {

        TimelineView(
            .animation(
                minimumInterval:
                    1.0 / 30.0,
                paused:
                    reduceMotion
            )
        ) {
            timeline in

            let time =
                timeline.date
                    .timeIntervalSinceReferenceDate

            let rotation =
                time * 155

            let reverseRotation =
                time * -95

            let pulse =
                0.97
                +
                0.06
                *
                (
                    (
                        sin(
                            time * 3.2
                        )
                        + 1
                    )
                    / 2
                )

            ZStack {

                Circle()
                    .stroke(
                        Color.blue
                            .opacity(0.10),
                        lineWidth: 8
                    )
                    .frame(
                        width: 104,
                        height: 104
                    )

                Circle()
                    .trim(
                        from: 0.05,
                        to: 0.69
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                .blue,
                                .indigo,
                                .purple
                            ],
                            startPoint:
                                .leading,
                            endPoint:
                                .trailing
                        ),
                        style:
                            StrokeStyle(
                                lineWidth: 8,
                                lineCap:
                                    .round
                            )
                    )
                    .frame(
                        width: 104,
                        height: 104
                    )
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                            ? 0
                            : rotation
                        )
                    )

                Circle()
                    .trim(
                        from: 0.10,
                        to: 0.34
                    )
                    .stroke(
                        Color.indigo
                            .opacity(0.48),
                        style:
                            StrokeStyle(
                                lineWidth: 3,
                                lineCap:
                                    .round
                            )
                    )
                    .frame(
                        width: 82,
                        height: 82
                    )
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                            ? 0
                            : reverseRotation
                        )
                    )

                ZStack {

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue
                                        .opacity(0.14),
                                    Color.indigo
                                        .opacity(0.10)
                                ],
                                startPoint:
                                    .topLeading,
                                endPoint:
                                    .bottomTrailing
                            )
                        )
                        .frame(
                            width: 66,
                            height: 66
                        )

                    Image(
                        systemName:
                            "doc.text.magnifyingglass"
                    )
                    .font(
                        .system(
                            size: 27,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
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
                }
                .scaleEffect(
                    reduceMotion
                    ? 1
                    : pulse
                )

                Circle()
                    .fill(.blue)
                    .frame(
                        width: 9,
                        height: 9
                    )
                    .shadow(
                        radius: 5
                    )
                    .offset(y: -60)
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                            ? 0
                            : rotation
                        )
                    )

                Circle()
                    .fill(.purple)
                    .frame(
                        width: 7,
                        height: 7
                    )
                    .offset(y: 57)
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                            ? 0
                            : reverseRotation
                        )
                    )
            }
            .frame(
                width: 128,
                height: 128
            )
        }
    }
}

