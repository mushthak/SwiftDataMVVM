//
//  SwiftDataMVVMApp.swift
//  SwiftDataMVVM
//
//  Created by Mushthak Ebrahim on 02/12/24.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataMVVMApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ManagedUserItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        
        let userStore: SwiftDataStore = SwiftDataStore(modelContainer: sharedModelContainer)
        let viewModel: UserViewModel = UserViewModel(userStore: userStore)
        
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
