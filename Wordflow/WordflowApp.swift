//
//  WordflowApp.swift
//  Wordflow
//
//  Created by Hiroshi Kodera on 2025-08-09.
//

import SwiftUI
import SwiftData

@main
struct WordflowApp: App {
    // DELAX Quality Management
    @State private var qualityManager = DelaxQualityManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IELTSTask.self,
            TypingResult.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema, 
            isStoredInMemoryOnly: true  // Phase A: Use in-memory during development
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(qualityManager)
                .onAppear {
                    // Initialize DELAX Quality System
                    qualityManager.initialize()
                    qualityManager.startMonitoring()
                    
                    print("🚀 Wordflow App launched successfully")
                    print("📊 DELAX Quality Management: Active")
                    print("🔗 DELAX Shared Package Integration: Ready")
                }
                .onDisappear {
                    // Cleanup when app is closing
                    qualityManager.stopMonitoring()
                    print("🛑 DELAX Quality Management: Stopped")
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // macOS Menu Commands
            CommandGroup(after: .newItem) {
                Button("New Document") {
                    // TODO: Add new document action
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("New Project") {
                    // TODO: Add new project action
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .help) {
                Button("Wordflow Help") {
                    // TODO: Add help action
                }
            }
        }
    }
}
