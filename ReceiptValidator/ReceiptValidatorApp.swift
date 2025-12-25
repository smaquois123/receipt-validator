//
//  ReceiptValidatorApp.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/23/25.
//

import SwiftUI
import SwiftData

@main
struct ReceiptValidatorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Receipt.self,
            ReceiptItem.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
