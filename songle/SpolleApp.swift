//
//  SpolleApp.swift
//  Spolle
//
//  Created by Ümit BAĞ on 7/2/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleMobileAds

@main
struct SpolleApp: App {
    
    init() {
        FirebaseApp.configure()
        AdMobManager.shared.initialize()
        
        // Track app launch for rating system
        AppRatingManager.shared.incrementAppLaunch()
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Artist.self,
            Guess.self,
            GameState.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
