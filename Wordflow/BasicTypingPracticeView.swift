//
//  BasicTypingPracticeView.swift
//  Wordflow - Typing Practice App
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
    @State private var showingCompletionModal = false
    @State private var showingCustomTaskCreation = false
    @State private var completionResult: TypingResult?
    
    // Audio Settings
    @State private var autoPlayAudio = true
    
    @FocusState private var isViewFocused: Bool
    @FocusState private var isInputFocused: Bool
    
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
        .focused($isViewFocused)
        .onAppear {
            setupRepositories()
            loadSampleTasksIfNeeded()
            setupTestManager()
            isViewFocused = true // フォーカスを設定
        }
        .sheet(isPresented: $showingCompletionModal, onDismiss: {
            // シートが閉じられた時にフォーカスを戻す
            DispatchQueue.main.async {
                self.isViewFocused = true
                if testManager.isActive {
                    self.isInputFocused = true
                }
            }
        }) {
            if let result = completionResult {
                TestCompletionView(
                    result: result,
                    timerMode: testManager.timerMode,
                    onRetry: {
                        showingCompletionModal = false
                        retryTest()
                    },
                    onNewTask: {
                        showingCompletionModal = false
                        resetTest()
                    },
                    onClose: {
                        showingCompletionModal = false
                        completionResult = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingCustomTaskCreation) {
            CustomTaskCreationView(
                onTaskCreated: { newTask in
                    selectedTask = newTask
                    resetTest()
                },
                taskRepository: taskRepository
            )
        }
        .onKeyPress(.leftArrow, phases: [.down, .repeat]) { keyPress in
            // Check if Shift key is pressed for rewind shortcut
            if keyPress.modifiers.contains(.shift) && ttsManager.isPlaying {
                ttsManager.rewind(seconds: 3.0)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return, phases: [.down]) { keyPress in
            // Enter: Start/Pause/Resume test
            if keyPress.modifiers.contains(.command) {
                // フォーカスを確保
                isViewFocused = true
                
                if !testManager.isActive && selectedTask != nil {
                    startTest()
                } else if testManager.isActive && !testManager.isPaused {
                    testManager.pauseTest()
                } else if testManager.isPaused {
                    testManager.resumeTest()
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape, phases: [.down]) { keyPress in
            // Escape: Stop test
            isViewFocused = true // フォーカスを確保
            if testManager.isActive {
                stopTest()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("r"), phases: [.down]) { keyPress in
            // R: Quick retry (when test is completed)
            isViewFocused = true // フォーカスを確保
            if keyPress.modifiers.contains(.command) && !testManager.isActive && selectedTask != nil {
                startTest()
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("タイピング練習")
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
                    
                    Button("Create Custom Task", systemImage: "plus") {
                        showingCustomTaskCreation = true
                    }
                    
                    Button("Load Sample Tasks") {
                        showingSampleTasks = true
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Export Results", systemImage: "square.and.arrow.up") {
                    exportResults()
                }
                .buttonStyle(.bordered)
                
                Toggle(isOn: $autoPlayAudio) {
                    HStack(spacing: 4) {
                        Image(systemName: autoPlayAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text("Auto Audio")
                    }
                }
                .toggleStyle(.button)
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
            .focused($isInputFocused)
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
                .focused($isInputFocused)
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
            // Control Buttons & Timer Mode
            HStack(spacing: 12) {
                Button("Start (⌘Enter)", systemImage: "play.fill") {
                    startTest()
                }
                .disabled(selectedTask == nil || testManager.isActive)
                .buttonStyle(.borderedProminent)
                
                Button("Pause (⌘Enter)", systemImage: "pause.fill") {
                    testManager.pauseTest()
                }
                .disabled(!testManager.isActive || testManager.isPaused)
                
                Button("Stop (Esc)", systemImage: "stop.fill") {
                    stopTest()
                }
                .disabled(!testManager.isActive)
                
                Divider()
                    .frame(height: 20)
                
                // Phase A: Enhanced Timer Mode Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("モード")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Timer Mode", selection: Binding(
                        get: { testManager.timerMode },
                        set: { testManager.setTimerMode($0) }
                    )) {
                        ForEach(TimerMode.allCases) { mode in
                            Text(mode.shortName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(testManager.isActive)
                    .frame(width: 140)
                }
            }
            
            Spacer()
            
            // Statistics Display
            HStack(spacing: 20) {
                StatisticView(
                    icon: "clock",
                    title: "Time (\(testManager.timerMode.shortName))",
                    value: timeString,
                    color: timerColor
                )
                
                // Phase A: Enhanced Net WPM with Quality Score
                EnhancedStatisticView(
                    icon: "speedometer",
                    title: "Net WPM",
                    value: String(format: "%.0f", testManager.netWPM),
                    subtitle: testManager.isPersonalBest ? "🏆 NEW BEST!" : personalBestString,
                    color: wpmColor,
                    isHighlighted: testManager.isPersonalBest
                )
                
                // Phase A: Quality Score display
                StatisticView(
                    icon: "star.fill",
                    title: "Quality",
                    value: String(format: "%.0f", testManager.qualityScore),
                    color: qualityColor
                )
                
                EnhancedStatisticView(
                    icon: "target",
                    title: "Accuracy",
                    value: String(format: "%.0f%%", testManager.characterAccuracy),
                    subtitle: String(format: "Words: %.0f%%", testManager.wordAccuracy),
                    color: accuracyColor,
                    isHighlighted: testManager.characterAccuracy >= 98
                )
                
                StatisticView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress",
                    value: String(format: "%.0f%%", testManager.completionPercentage),
                    color: .purple
                )
                
                // Phase A: Gross WPM display (smaller)
                StatisticView(
                    icon: "keyboard",
                    title: "Gross WPM",
                    value: String(format: "%.0f", testManager.grossWPM),
                    color: .gray
                )
                
                if testManager.wpmVariation > 0 {
                    StatisticView(
                        icon: "waveform.path.ecg",
                        title: "Consistency",
                        value: String(format: "%.0f%%", 100 - testManager.wpmVariation),
                        color: consistencyColor
                    )
                }
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
    
    private var timerColor: Color {
        if !testManager.isActive {
            return .blue
        }
        
        let remainingRatio = testManager.remainingTime / testManager.timerMode.duration
        
        if remainingRatio > 0.5 {
            return .blue
        } else if remainingRatio > 0.25 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var wpmColor: Color {
        let wpm = testManager.netWPM
        if wpm >= 60 { return .green }
        else if wpm >= 40 { return .blue }
        else if wpm >= 25 { return .orange }
        else { return .gray }
    }
    
    // Phase A: Quality Score color coding
    private var qualityColor: Color {
        let quality = testManager.qualityScore
        if quality >= 50 { return .green }
        else if quality >= 30 { return .blue }
        else if quality >= 15 { return .orange }
        else { return .red }
    }
    
    private var accuracyColor: Color {
        let accuracy = testManager.characterAccuracy
        if accuracy >= 98 { return .green }
        else if accuracy >= 95 { return .blue }
        else if accuracy >= 90 { return .orange }
        else { return .red }
    }
    
    private var consistencyColor: Color {
        let consistency = 100 - testManager.wpmVariation
        if consistency >= 90 { return .green }
        else if consistency >= 80 { return .blue }
        else if consistency >= 70 { return .orange }
        else { return .red }
    }
    
    private var personalBestString: String {
        if let best = testManager.getPersonalBest(for: testManager.timerMode) {
            return String(format: "Best: %.0f", best.netWPM)
        }
        return "No record"
    }
    
    // MARK: - Methods
    
    private func setupRepositories() {
        taskRepository = IELTSTaskRepository(modelContext: modelContext)
        resultRepository = TypingResultRepository(modelContext: modelContext)
    }
    
    private func setupTestManager() {
        testManager.onTimeUp = {
            Task { @MainActor in
                // Stop TTS when time is up
                self.ttsManager.stop()
                
                // 2秒間の余白を追加
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                
                if let result = self.testManager.endTest() {
                    self.completionResult = result
                    self.resultRepository?.saveResult(result)
                    self.showingCompletionModal = true
                }
            }
        }
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
        isViewFocused = true // フォーカスを確保
        testManager.startTest(with: task)
        userInput = ""
        
        // インプットエリアにフォーカス
        DispatchQueue.main.async {
            self.isInputFocused = true
        }
        
        // Auto-play audio if enabled
        if autoPlayAudio {
            playTTS()
        }
    }
    
    private func stopTest() {
        if let result = testManager.endTest() {
            resultRepository?.saveResult(result)
            completionResult = result
            showingCompletionModal = true
        }
        isViewFocused = true // フォーカスを確保
        resetTest()
    }
    
    private func retryTest() {
        guard let task = selectedTask else { return }
        userInput = ""
        ttsManager.stop()
        testManager.startTest(with: task)
        
        // インプットエリアにフォーカス
        DispatchQueue.main.async {
            self.isInputFocused = true
        }
        
        // Auto-play audio if enabled
        if autoPlayAudio {
            playTTS()
        }
    }
    
    private func resetTest() {
        userInput = ""
        ttsManager.stop()
        completionResult = nil
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
        
        // Phase A: Use basic error counter for highlighting (keeping existing pattern)
        let errorInfo = errorCounter.countBasicErrors(input: userInput, target: task.modelAnswer)
        var attributedString = AttributedString(userInput)
        
        // Apply basic highlighting based on error positions
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

struct EnhancedStatisticView: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: isHighlighted ? .bold : .regular))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(isHighlighted ? .bold : .medium)
                        .foregroundColor(isHighlighted ? color : .primary)
                }
            }
            
            Text(subtitle)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(isHighlighted ? color : .secondary)
                .fontWeight(isHighlighted ? .semibold : .regular)
        }
        .padding(.vertical, 2)
        .background(isHighlighted ? color.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    BasicTypingPracticeView()
        .modelContainer(for: [IELTSTask.self, TypingResult.self], inMemory: true)
}