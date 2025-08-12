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
    @State private var showingErrorAnalysis = false
    @State private var currentErrorAnalysis: DetailedErrorAnalysis?
    
    // Audio Settings
    @State private var autoPlayAudio = true
    
    // Debounce for retry operations
    @State private var lastRetryTime: Date = Date.distantPast
    
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
                    resultRepository: resultRepository,
                    testManager: testManager, // 🔧 FIX: Pass test manager for personal best access
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
        .sheet(isPresented: $showingErrorAnalysis) {
            if let analysis = currentErrorAnalysis {
                NavigationView {
                    ErrorAnalysisView(analysis: analysis)
                        .navigationTitle("Error Analysis Report")
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Done") {
                                    showingErrorAnalysis = false
                                }
                            }
                        }
                }
                .frame(minWidth: 600, minHeight: 500)
            }
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
                    // テスト開始
                    startTest()
                } else if testManager.isActive && !testManager.isPaused {
                    // タイマー中：一時停止
                    testManager.pauseTest()
                } else if testManager.isPaused {
                    // 一時停止中：再開
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
            // R: Restart during active test or retry when test is completed
            isViewFocused = true // フォーカスを確保
            if keyPress.modifiers.contains(.command) && selectedTask != nil {
                if testManager.isActive && !showingCompletionModal {
                    // テスト中：リスタート
                    restartTest()
                    return .handled
                } else if !testManager.isActive && !showingCompletionModal {
                    // テスト完了後：再試行
                    startTest()
                    return .handled
                }
            }
            return .ignored
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Text("タイピングプロジェクト")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("v1.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
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
                
                Button("Error Analysis", systemImage: "chart.bar.doc.horizontal") {
                    performErrorAnalysis()
                }
                .buttonStyle(.bordered)
                .disabled(userInput.isEmpty || selectedTask == nil)
                
                Button("📊 JSON Telemetry", systemImage: "doc.text.fill") {
                    exportCurrentTelemetry()
                }
                .buttonStyle(.bordered)
                .disabled(selectedTask == nil)
                .help("Export current typing session telemetry as JSON")
                
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
                    RealTimeTextComparisonView(
                        targetText: task.modelAnswer,
                        userInput: userInput,
                        showCursor: testManager.isActive
                    )
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy Text", systemImage: "doc.on.doc") {
                            copyTargetText()
                        }
                        .keyboardShortcut("c", modifiers: .command)
                        
                        Button("Select All", systemImage: "selection.pin.in.out") {
                            selectAllTargetText()
                        }
                        .keyboardShortcut("a", modifiers: .command)
                    }
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
                
                Button(testManager.isPaused ? "Resume (⌘Enter)" : "Pause (⌘Enter)", systemImage: testManager.isPaused ? "play.fill" : "pause.fill") {
                    if testManager.isPaused {
                        testManager.resumeTest()
                    } else {
                        testManager.pauseTest()
                    }
                }
                .disabled(!testManager.isActive)
                
                Button("Restart (⌘R)", systemImage: "arrow.clockwise") {
                    restartTest()
                }
                .disabled(!testManager.isActive)
                
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
                
                // 🚨 ENHANCED SANITY CHECK: 3つの必須検証表示
                if testManager.isActive && !userInput.isEmpty {
                    VStack(spacing: 2) {
                        Text("Validation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            // Net WPM formula validation
                            let netFormula = testManager.currentScore.grossWPM * (testManager.currentScore.accuracy / 100.0)
                            let formulaDeviation = abs(testManager.currentScore.netWPM - netFormula) / max(testManager.currentScore.netWPM, 0.01)
                            let netValid = formulaDeviation <= 0.03
                            
                            HStack(spacing: 2) {
                                Image(systemName: netValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(netValid ? .green : .red)
                                Text("Formula")
                                    .font(.caption2)
                                    .foregroundColor(netValid ? .green : .red)
                            }
                            
                            // KSPC validation
                            let kspcExpected = userInput.count > 0 ? Double(testManager.totalKeystrokes) / Double(userInput.count) : 1.0
                            let kspcDeviation = abs(testManager.currentScore.kspc - kspcExpected) / max(testManager.currentScore.kspc, 0.01)
                            let kspcValid = kspcDeviation <= 0.03
                            
                            HStack(spacing: 2) {
                                Image(systemName: kspcValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(kspcValid ? .green : .red)
                                Text("KSPC")
                                    .font(.caption2)
                                    .foregroundColor(kspcValid ? .green : .red)
                            }
                            
                            // Duration validation
                            let durationValid = testManager.elapsedTime >= 60.0
                            HStack(spacing: 2) {
                                Image(systemName: durationValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(durationValid ? .green : .red)
                                Text("Time")
                                    .font(.caption2)
                                    .foregroundColor(durationValid ? .green : .red)
                            }
                        }
                    }
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
    
    
    // MARK: - Computed Properties
    
    // Safe sanity check computation
    private var isSanityCheckValid: Bool {
        guard testManager.isActive, !userInput.isEmpty else { return true }
        return testManager.currentScore.isFormulaValid
    }
    
    // MARK: - Methods
    
    private func setupRepositories() {
        taskRepository = IELTSTaskRepository(modelContext: modelContext)
        resultRepository = TypingResultRepository(modelContext: modelContext)
    }
    
    private func setupTestManager() {
        testManager.onTimeUp = {
            // 🔧 IMMEDIATE FIX: Stop TTS and process result immediately
            self.ttsManager.stop()
            
            // 既に結果表示中の場合は何もしない（重複防止）
            guard !self.showingCompletionModal else { return }
            
            if let result = self.testManager.endTest() {
                self.completionResult = result
                self.resultRepository?.saveResult(result)
                
                // 🔧 FIX: Use shorter delay and ensure UI update on main thread
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        guard testManager.isActive else { return }
        
        // TTS停止
        ttsManager.stop()
        
        // 既に結果表示中の場合は何もしない（重複防止）
        guard !showingCompletionModal else { return }
        
        if let result = testManager.endTest() {
            resultRepository?.saveResult(result)
            completionResult = result
            showingCompletionModal = true
        }
        
        userInput = ""
        isViewFocused = true // フォーカスを確保
    }
    
    private func retryTest() {
        guard let task = selectedTask else { return }
        
        // デバウンス: 1秒以内の重複実行を防ぐ
        let now = Date()
        if now.timeIntervalSince(lastRetryTime) < 1.0 {
            return
        }
        lastRetryTime = now
        
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
    
    private func restartTest() {
        guard let task = selectedTask else { return }
        // 現在のテストを停止して新しいテストを開始
        _ = testManager.endTest() // 結果は保存しない（警告回避のため破棄）
        userInput = ""
        ttsManager.stop()
        testManager.startTest(with: task)
        
        // フォーカスを確実に設定（少し遅延を入れる）
        DispatchQueue.main.async {
            self.isViewFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        
        // 🔧 CRASH FIX: Use simple fallback approach to avoid index manipulation crashes
        // If userInput is empty, return as-is
        guard !userInput.isEmpty else { return AttributedString(userInput) }
        
        // Use character-by-character comparison instead of complex AttributedString index manipulation
        let errorInfo = errorCounter.countBasicErrors(input: userInput, target: task.modelAnswer)
        var result = AttributedString("")
        
        // Build the attributed string character by character (safer approach)
        for (index, char) in userInput.enumerated() {
            var charString = AttributedString(String(char))
            
            if errorInfo.errorPositions.contains(index) {
                charString.backgroundColor = .red.opacity(0.3)
            } else {
                charString.backgroundColor = .green.opacity(0.3)
            }
            
            result.append(charString)
        }
        
        return result
    }
    
    // MARK: - Target Text Helper Methods
    
    private func copyTargetText() {
        guard let task = selectedTask else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.modelAnswer, forType: .string)
    }
    
    private func selectAllTargetText() {
        // Provide visual feedback for text selection
        NSSound(named: "Tink")?.play()
    }
    
    // MARK: - Telemetry Export Methods
    
    private func exportCurrentTelemetry() {
        guard let task = selectedTask else { return }
        
        // Get current metrics from testManager
        let elapsedTime = testManager.isActive ? testManager.elapsedTime : max(1.0, testManager.elapsedTime)
        let currentInput = userInput
        
        // Force calculate current scoring if test is active
        if testManager.isActive {
            testManager.updateInput(currentInput)
        }
        
        let score = testManager.currentScore
        
        // 🔧 SANITY CHECKS: マニュアルエクスポート前バリデーション
        let netFormula = score.grossWPM * (score.accuracy / 100.0)
        let formulaDeviation = abs(score.netWPM - netFormula) / max(score.netWPM, 0.01)
        let kspcExpected = currentInput.count > 0 ? Double(testManager.totalKeystrokes) / Double(currentInput.count) : 1.0
        let kspcDeviation = abs(score.kspc - kspcExpected) / max(score.kspc, 0.01)
        
        let formulaValid = formulaDeviation <= 0.03
        let kspcValid = kspcDeviation <= 0.03
        let durationValid = elapsedTime >= 10.0  // マニュアルは緩い基準
        
        if !formulaValid || !kspcValid {
            showTelemetryAlert(message: "🚨 バリデーション失敗 - エクスポート禁止\n\n数式チェック: \(formulaValid ? "✅" : "❌")\nKSPCチェック: \(kspcValid ? "✅" : "❌")\n\nデータ整合性に問題があります。")
            return
        }
        
        // 🔧 SCHEMA v1.1: マニュアルエクスポート用JSONスキーマ
        let telemetryData: [String: Any] = [
            "run_id": UUID().uuidString,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "mode": testManager.isTimeAttackMode ? "no-delete" : "normal",
            "experiment_mode": testManager.isTimeAttackMode ? "time_attack" : "standard",
            "task_topic": task.topic,
            "duration_sec": elapsedTime,
            "chars_ref": task.modelAnswer.count,
            "chars_typed": currentInput.count,
            "unfixed_errors": score.unfixedErrors,
            "gross_wpm": score.grossWPM,
            "char_accuracy": score.accuracy,
            "net_wpm": score.netWPM,
            "keystrokes_total": testManager.totalKeystrokes,
            "backspace_count": testManager.correctionCost,
            "kspc": score.kspc,
            "backspace_rate": score.backspaceRate / 100.0,
            "formula_valid": formulaValid,
            "formula_deviation": formulaDeviation,
            "app_version": "1.1",
            "device_info": getDeviceInfo()
        ]
        
        // Convert to JSON and save
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: telemetryData, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                saveCurrentTelemetryToFile(jsonString, task: task)
            }
        } catch {
            print("⚠️ Failed to create telemetry JSON: \(error)")
            showTelemetryAlert(message: "Failed to create telemetry data: \(error.localizedDescription)")
        }
    }
    
    private func saveCurrentTelemetryToFile(_ jsonString: String, task: IELTSTask) {
        let fileManager = FileManager.default
        
        // Get Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access Documents directory")
            showTelemetryAlert(message: "Could not access Documents directory")
            return
        }
        
        // Create WordflowTelemetry directory
        let telemetryURL = documentsURL.appendingPathComponent("WordflowTelemetry")
        
        do {
            if !fileManager.fileExists(atPath: telemetryURL.path) {
                try fileManager.createDirectory(at: telemetryURL, withIntermediateDirectories: true)
            }
            
            // Create filename with timestamp and task info
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let mode = testManager.isTimeAttackMode ? "no-delete" : "normal"
            let filename = "wordflow_v1.1_\(mode)_manual_\(formatter.string(from: Date())).json"
            let fileURL = telemetryURL.appendingPathComponent(filename)
            
            // Write JSON to file
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📁 Manual telemetry saved: \(fileURL.path)")
            
            // Show success and open folder
            showTelemetryAlert(message: "JSON telemetry exported successfully!\n\nFile: \(filename)\nLocation: ~/Documents/WordflowTelemetry/")
            
            // Automatically open the telemetry folder
            NSWorkspace.shared.open(telemetryURL)
            
        } catch {
            print("⚠️ Failed to save telemetry file: \(error)")
            showTelemetryAlert(message: "Failed to save telemetry file: \(error.localizedDescription)")
        }
    }
    
    private func showTelemetryAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "JSON Telemetry Export"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// デバイス情報を取得
    private func getDeviceInfo() -> String {
        #if os(macOS)
        let modelName = ProcessInfo.processInfo.machineHardwareName ?? "Unknown Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(modelName) - \(osVersion)"
        #else
        return "Unknown Device"
        #endif
    }
    
    // MARK: - Error Analysis Methods
    
    private func performErrorAnalysis() {
        guard let task = selectedTask, !userInput.isEmpty else { return }
        
        let analysis = errorCounter.analyzeErrors(input: userInput, target: task.modelAnswer)
        currentErrorAnalysis = analysis
        showingErrorAnalysis = true
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