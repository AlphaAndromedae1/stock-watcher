import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "star.fill") }

            IdeasView()
                .tabItem { Label("Ideas", systemImage: "sparkles") }

            NavigationStack {
                SearchView()
                    .navigationTitle("Search")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
        }
    }
}

#Preview {
    RootView()
}
