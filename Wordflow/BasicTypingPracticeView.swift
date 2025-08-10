//
//  BasicTypingPracticeView.swift
//  Wordflow - IELTS Writing Practice App
//

import SwiftUI
import SwiftData

struct BasicTypingPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IELTSTask.createdDate, order: .reverse) private var tasks: [IELTSTask]
    
    // Managers
    @State private var testManager = TypingTestManager()
    @State private var ttsManager = BasicTTSManager()
    @State private var errorCounter = BasicErrorCounter()
    
    // Repositories
    @State private var taskRepository: IELTSTaskRepository?
    @State private var resultRepository: TypingResultRepository?
    @State private var exportManager = ExportManager()
    
    // UI State
    @State private var selectedTask: IELTSTask?
    @State private var userInput = ""
    @State private var showingSampleTasks = false
    @State private var showingExport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main Content - 3 Panel Layout
            HStack(spacing: 0) {
                // Target Text Panel (45%)
                targetTextPanel
                
                Divider()
                
                // Input Area Panel (45%)
                inputAreaPanel
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Control & Statistics Panel (10%)
            controlStatisticsPanel
        }
        .onAppear {
            setupRepositories()
            loadSampleTasksIfNeeded()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("IELTS Typing Practice")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            if let task = selectedTask {
                Text(task.taskType.displayName)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Menu("Tasks") {
                    ForEach(tasks) { task in
                        Button("\(task.taskType.shortName): \(task.topic)") {
                            selectedTask = task
                            resetTest()
                        }
                    }
                    
                    Divider()
                    
                    Button("Load Sample Tasks") {
                        showingSampleTasks = true
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Export Results", systemImage: "square.and.arrow.up") {
                    exportResults()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    // MARK: - Target Text Panel
    
    private var targetTextPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel Header
            HStack {
                Text("Target Text")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let task = selectedTask {
                    Text("(\(task.wordCount) chars)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // TTS Controls
                if selectedTask != nil {
                    HStack(spacing: 8) {
                        Button("Play", systemImage: "play.fill") {
                            playTTS()
                        }
                        .disabled(ttsManager.isPlaying)
                        
                        if ttsManager.isPlaying {
                            Button("Pause", systemImage: "pause.fill") {
                                ttsManager.pause()
                            }
                            .disabled(ttsManager.isPaused)
                            
                            Button("Stop", systemImage: "stop.fill") {
                                ttsManager.stop()
                            }
                        }
                        
                        Menu(ttsManager.playbackSpeed.displayName) {
                            ForEach(TTSSpeed.allCases, id: \.self) { speed in
                                Button(speed.displayName) {
                                    ttsManager.setSpeed(speed)
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Target Text Display
            ScrollView {
                if let task = selectedTask {
                    Text(task.modelAnswer)
                        .font(.body)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Select a task to begin")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Input Area Panel
    
    private var inputAreaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel Header
            HStack {
                Text("Your Input")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("(\(userInput.count) chars)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Input Text Area
            VStack {
                if testManager.isActive {
                    highlightedInputView
                } else {
                    basicInputView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
    
    private var basicInputView: some View {
        TextEditor(text: $userInput)
            .font(.body)
            .disabled(!testManager.isActive)
            .onChange(of: userInput) { _, newValue in
                testManager.updateInput(newValue)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var highlightedInputView: some View {
        ScrollView {
            Text(getHighlightedText())
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .overlay(
            TextEditor(text: $userInput)
                .font(.body)
                .background(Color.clear)
                .onChange(of: userInput) { _, newValue in
                    testManager.updateInput(newValue)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Control & Statistics Panel
    
    private var controlStatisticsPanel: some View {
        HStack {
            // Control Buttons
            HStack(spacing: 12) {
                Button("Start", systemImage: "play.fill") {
                    startTest()
                }
                .disabled(selectedTask == nil || testManager.isActive)
                .buttonStyle(.borderedProminent)
                
                Button("Pause", systemImage: "pause.fill") {
                    testManager.pauseTest()
                }
                .disabled(!testManager.isActive || testManager.isPaused)
                
                Button("Stop", systemImage: "stop.fill") {
                    stopTest()
                }
                .disabled(!testManager.isActive)
            }
            
            Spacer()
            
            // Statistics Display
            HStack(spacing: 20) {
                StatisticView(
                    icon: "clock",
                    title: "Time",
                    value: timeString,
                    color: .blue
                )
                
                StatisticView(
                    icon: "speedometer",
                    title: "WPM",
                    value: String(format: "%.0f", testManager.currentWPM),
                    color: .green
                )
                
                StatisticView(
                    icon: "target",
                    title: "Accuracy",
                    value: String(format: "%.0f%%", testManager.accuracy),
                    color: .orange
                )
                
                StatisticView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress",
                    value: String(format: "%.0f%%", testManager.completionPercentage),
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Views
    
    private var timeString: String {
        let time = testManager.isActive ? testManager.remainingTime : testManager.elapsedTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Methods
    
    private func setupRepositories() {
        taskRepository = IELTSTaskRepository(modelContext: modelContext)
        resultRepository = TypingResultRepository(modelContext: modelContext)
    }
    
    private func loadSampleTasksIfNeeded() {
        if tasks.isEmpty {
            createSampleTasks()
        } else {
            selectedTask = tasks.first
        }
    }
    
    private func createSampleTasks() {
        guard let repo = taskRepository else { return }
        
        // Sample Task 1
        _ = repo.createTask(
            taskType: .task1,
            topic: "Library Opening Hours Chart",
            modelAnswer: "The chart shows the opening hours of a city library throughout the week. The library operates from Monday to Sunday with varying schedules. On weekdays (Monday to Friday), the library opens at 9:00 AM and closes at 8:00 PM, providing eleven hours of service daily. Weekend hours differ significantly, with Saturday opening from 10:00 AM to 6:00 PM (eight hours) and Sunday offering reduced hours from 12:00 PM to 5:00 PM (five hours). The longest operating days are weekdays, while Sunday has the shortest opening period.",
            targetBandScore: 7.0
        )
        
        // Sample Task 2
        _ = repo.createTask(
            taskType: .task2,
            topic: "Technology and Education",
            modelAnswer: "In recent years, technology has revolutionized education, transforming how students learn and teachers instruct. This essay will discuss both the advantages and disadvantages of incorporating technology into educational settings. The primary benefit of educational technology is enhanced accessibility to information. Students can access vast databases, online libraries, and educational platforms from anywhere, breaking geographical barriers to learning. Additionally, interactive multimedia content makes complex concepts easier to understand and retain. However, excessive reliance on technology poses significant drawbacks. Students may develop shortened attention spans and reduced critical thinking skills when information is readily available. Furthermore, the digital divide creates inequality, as not all students have equal access to technological resources. In conclusion, while technology offers valuable educational tools, it should complement rather than replace traditional teaching methods to ensure balanced learning experiences.",
            targetBandScore: 7.5
        )
        
        selectedTask = tasks.first
    }
    
    private func startTest() {
        guard let task = selectedTask else { return }
        testManager.startTest(with: task)
        userInput = ""
    }
    
    private func stopTest() {
        if let result = testManager.endTest() {
            resultRepository?.saveResult(result)
        }
        resetTest()
    }
    
    private func resetTest() {
        userInput = ""
        ttsManager.stop()
    }
    
    private func playTTS() {
        guard let task = selectedTask else { return }
        ttsManager.playFullText(task.modelAnswer)
    }
    
    private func exportResults() {
        guard let repo = resultRepository else { return }
        let results = repo.fetchAllResults()
        let csv = exportManager.exportResultsToCSV(results: results)
        exportManager.saveCSVToFile(csv: csv)
    }
    
    private func getHighlightedText() -> AttributedString {
        guard let task = selectedTask else {
            return AttributedString(userInput)
        }
        
        let errorInfo = errorCounter.countBasicErrors(input: userInput, target: task.modelAnswer)
        var attributedString = AttributedString(userInput)
        
        // Apply basic highlighting
        for (index, _) in userInput.enumerated() {
            if errorInfo.errorPositions.contains(index) {
                let range = attributedString.index(attributedString.startIndex, offsetByCharacters: index)..<attributedString.index(attributedString.startIndex, offsetByCharacters: index + 1)
                attributedString[range].backgroundColor = .red.opacity(0.3)
            } else {
                let range = attributedString.index(attributedString.startIndex, offsetByCharacters: index)..<attributedString.index(attributedString.startIndex, offsetByCharacters: index + 1)
                attributedString[range].backgroundColor = .green.opacity(0.3)
            }
        }
        
        return attributedString
    }
}

// MARK: - Supporting Views

struct StatisticView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BasicTypingPracticeView()
        .modelContainer(for: [IELTSTask.self, TypingResult.self], inMemory: true)
}