import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
        } detail: {
            switch selection {
            case .home: HomeView()
            case .discussions: DiscussionsView()
            case .people: PeopleView()
            case .settings: SettingsView()
            }
        }
    }
}

enum SidebarItem: String, CaseIterable {
    case home = "Home"
    case discussions = "Discussions"
    case people = "People"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .discussions: return "bubble.left.and.bubble.right.fill"
        case .people: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
