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
            TypingResult.self,
            TimeAttackResult.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)

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
                    
                    // Initialize sample data
                    initializeSampleData()
                    
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
    
    // MARK: - Sample Data Initialization
    
    private func initializeSampleData() {
        let context = sharedModelContainer.mainContext
        
        // Check if sample data already exists
        let descriptor = FetchDescriptor<IELTSTask>()
        do {
            let existingTasks = try context.fetch(descriptor)
            if !existingTasks.isEmpty {
                print("📝 Sample data already exists (\(existingTasks.count) tasks)")
                return
            }
        } catch {
            print("❌ Error checking for existing tasks: \(error)")
        }
        
        // Create sample tasks
        let sampleTasks = [
            (
                taskType: TaskType.task1,
                topic: "Media Violence Debate",
                modelAnswer: """
The argument that media violence negatively affects society is a recurring and complex debate. I partially agree with this assertion, but I believe the impact is not universal. The effect of such depictions varies critically on their context and purpose, distinguishing between violence as mere entertainment and violence as social commentary.

On the one hand, when violence is commercialized and presented without context, it can indeed be detrimental. In a media landscape driven by profit, sensationalism often takes precedence over responsible storytelling. This can desensitize audiences, particularly younger ones, to the real-world consequences of violence and may trivialize human suffering. When violence is treated as a spectacle, it risks normalizing aggression as an acceptable or exciting part of life.
""",
                bandScore: 7.5
            ),
            (
                taskType: TaskType.task2,
                topic: "Technology and Human Connection",
                modelAnswer: """
In our increasingly digital world, the relationship between technology and human connection has become a subject of intense debate. While some argue that technological advances have strengthened our ability to communicate and maintain relationships, others contend that these same innovations have created barriers to genuine human interaction. I believe that technology serves as both a bridge and a barrier to meaningful human connection, depending largely on how we choose to employ it.

Technology has undeniably expanded our capacity to connect with others across vast distances and time zones. Social media platforms, video calling applications, and instant messaging services have made it possible to maintain relationships that might otherwise have faded due to geographical constraints. For instance, families separated by immigration can now share daily experiences through video calls, creating a sense of presence that was impossible just decades ago. Similarly, online communities have enabled individuals with niche interests or rare conditions to find support networks that simply don't exist in their immediate physical environment.

However, the convenience of digital communication has also introduced new challenges to the depth and quality of our interpersonal relationships. The ease with which we can send a quick text message or leave a brief comment on social media has, in many cases, replaced longer, more thoughtful conversations. This shift toward brevity and immediacy can result in relationships that feel superficial, lacking the nuance and emotional depth that comes from face-to-face interaction and sustained dialogue.

Furthermore, the curated nature of online personas can create false impressions and unrealistic expectations in relationships. When we primarily interact through carefully selected photos and status updates, we may develop connections based on incomplete or idealized versions of ourselves and others, rather than accepting and embracing the full complexity of human nature.
""",
                bandScore: 8.0
            ),
            (
                taskType: TaskType.task1,
                topic: "Environmental Policy Analysis",
                modelAnswer: """
Climate change represents one of the most pressing challenges of our time, requiring immediate and comprehensive action across all sectors of society. The scientific consensus is clear: human activities, particularly the burning of fossil fuels, have led to unprecedented levels of greenhouse gas emissions that are fundamentally altering our planet's climate system.

The consequences of inaction are already visible in rising global temperatures, melting ice caps, more frequent extreme weather events, and disruptions to ecosystems worldwide. These changes threaten not only environmental stability but also economic security, public health, and social equity.

Addressing climate change requires a multi-faceted approach that combines technological innovation, policy reform, and behavioral change. Governments must implement robust carbon pricing mechanisms, invest in renewable energy infrastructure, and establish stringent emissions standards for industries. Simultaneously, individuals must embrace sustainable practices in their daily lives, from reducing energy consumption to making conscious choices about transportation and consumption.
""",
                bandScore: 7.0
            )
        ]
        
        // Insert sample tasks
        for (taskType, topic, modelAnswer, bandScore) in sampleTasks {
            let task = IELTSTask(
                taskType: taskType,
                topic: topic,
                modelAnswer: modelAnswer,
                targetBandScore: bandScore
            )
            context.insert(task)
        }
        
        // Save the context
        do {
            try context.save()
            print("✅ Sample data initialized successfully (\(sampleTasks.count) tasks)")
        } catch {
            print("❌ Error saving sample data: \(error)")
        }
    }
}
