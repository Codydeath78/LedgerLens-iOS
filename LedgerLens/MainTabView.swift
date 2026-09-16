// Adds the Insights tab without changing Analyze/History.

import SwiftUI


struct MainTabView: View {

    @StateObject private var documentWorkspace =
        DocumentWorkspace()


    var body: some View {

        TabView(
            selection:
                $documentWorkspace
                    .selectedTab
        ) {

            HomeDashboardView()
                .tag(
                    DocumentWorkspace
                        .Tab
                        .home
                )
                .tabItem {

                    Label(
                        "Home",
                        systemImage:
                            "house.fill"
                    )
                }


            ContentView()
                .tag(
                    DocumentWorkspace
                        .Tab
                        .analyze
                )
                .tabItem {

                    Label(
                        "Analyze",
                        systemImage:
                            "sparkles"
                    )
                }


            CrossDocumentHubView()
                .tag(
                    DocumentWorkspace
                        .Tab
                        .insights
                )
                .tabItem {

                    Label(
                        "Insights",
                        systemImage:
                            "chart.xyaxis.line"
                    )
                }


            DocumentHistoryView()
                .tag(
                    DocumentWorkspace
                        .Tab
                        .history
                )
                .tabItem {

                    Label(
                        "History",
                        systemImage:
                            "clock.arrow.circlepath"
                    )
                }
        }
        .tint(
            .blue
        )
        .environmentObject(
            documentWorkspace
        )
    }
}
