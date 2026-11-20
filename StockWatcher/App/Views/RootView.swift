import SwiftUI

struct RootView: View {
    @StateObject private var router = DeepLinkRouter()
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            WatchlistView(router: router)
                .tabItem { Label("Watchlist", systemImage: "star.fill") }
                .tag(0)

            IdeasView()
                .tabItem { Label("Ideas", systemImage: "sparkles") }
                .tag(1)

            NavigationStack {
                SearchView()
                    .navigationTitle("Search")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(2)

            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .onOpenURL { url in
            router.handle(url)
            if router.target != nil { tab = 0 }
        }
    }
}

#Preview {
    RootView()
}
