//
//  TimeAttackView.swift
//  Wordflow - Time Attack Mode UI
//
//  Created by Claude Code on 2025/08/11.
//

import SwiftUI
import SwiftData

struct TimeAttackView: View {
    // MARK: - Environment & Dependencies
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IELTSTask.createdDate, order: .reverse) private var tasks: [IELTSTask]
    
    // MARK: - State Management
    
    @State private var timeAttackManager: TimeAttackManager
    @State private var personalBestManager: PersonalBestManager
    @State private var timeAttackRepository: TimeAttackResultRepository
    @State private var typingTestManager: TypingTestManager
    
    // MARK: - UI State
    
    @State private var selectedTask: IELTSTask?
    @State private var userInput = ""
    @State private var showingCompletionModal = false
    @State private var currentResult: TimeAttackResult?
    @State private var showCompletionAnimation = false
    @State private var completionBurst = false
    
    // MARK: - Focus Management
    
    @FocusState private var isViewFocused: Bool
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Initialization
    
    init() {
        let typingManager = TypingTestManager()
        let personalBest = PersonalBestManager()
        
        // Create placeholder repository - will be properly initialized in onAppear
        let placeholderRepository = TimeAttackResultRepository(modelContext: nil)
        let timeAttack = TimeAttackManager(
            typingTestManager: typingManager,
            repository: placeholderRepository,
            personalBestManager: personalBest
        )
        
        self._typingTestManager = State(initialValue: typingManager)
        self._personalBestManager = State(initialValue: personalBest)
        self._timeAttackRepository = State(initialValue: placeholderRepository)
        self._timeAttackManager = State(initialValue: timeAttack)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Task Selection
            headerView
            
            Divider()
            
            // Main Content - 3 Panel Layout
            HStack(spacing: 0) {
                // Target Text Panel (45%)
                targetTextPanel
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Input Area Panel (35%)
                inputAreaPanel
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Timer & Stats Panel (20%)
                timerStatsPanel
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Control Panel
            controlPanel
        }
        .focused($isViewFocused)
        .overlay(
            // Completion Animation Overlay
            completionAnimationOverlay
                .opacity(showCompletionAnimation ? 1 : 0)
                .allowsHitTesting(false)
        )
        .onAppear {
            setupInitialState()
            isViewFocused = true
        }
        .sheet(isPresented: $showingCompletionModal) {
            if let result = currentResult {
                TimeAttackCompletionView(
                    result: result,
                    isNewRecord: timeAttackManager.isNewRecord,
                    achievedBadges: timeAttackManager.achievedBadges,
                    onRetry: {
                        showingCompletionModal = false
                        retryCurrentTask()
                    },
                    onNewTask: {
                        showingCompletionModal = false
                        resetForNewTask()
                    },
                    onClose: {
                        showingCompletionModal = false
                        showCompletionAnimation = false
                        completionBurst = false
                    }
                )
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Time Attack Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if let task = selectedTask {
                Text("\(task.taskType.displayName) - \(task.topic)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Task Selection Menu
            Menu("Select Task") {
                ForEach(tasks) { task in
                    Button("\(task.taskType.shortName): \(task.topic)") {
                        selectTask(task)
                    }
                }
                
                Divider()
                
                Button("Show All Tasks", systemImage: "list.bullet") {
                    // TODO: Show task browser
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .border(Color.orange, width: 1)
    }
    
    // MARK: - Target Text Panel
    
    private var targetTextPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.primary)
                Text("Target Text")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let task = selectedTask {
                    Text("(\(task.wordCount) chars)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selectable text hint
                if selectedTask != nil {
                    Text("Right-click to copy")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .italic()
                }
            }
            
            // Target Text Display
            ScrollView {
                if let task = selectedTask {
                    VStack(alignment: .leading, spacing: 16) {
                        RealTimeTextComparisonView(
                            targetText: task.modelAnswer,
                            userInput: userInput,
                            showCursor: timeAttackManager.isActive
                        )
                        .frame(minHeight: 120)
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
                        
                        // Personal Best Display
                        if let stats = timeAttackManager.currentStats {
                            personalBestCard(stats)
                        }
                    }
                } else {
                    VStack {
                        Image(systemName: "timer")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Select a task to begin")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Time Attack Mode")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
    }
    
    private func personalBestCard(_ stats: TimeAttackStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Records")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🏆 Best Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats.formattedPersonalBest)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("📊 Attempts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.attempts)")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Input Area Panel
    
    private var inputAreaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel Header
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.primary)
                Text("Your Input")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("(\(userInput.count) chars)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if timeAttackManager.isActive {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text("Backspaces: \(timeAttackManager.currentCorrectionCost)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .scaleEffect(timeAttackManager.currentCorrectionCost > 0 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: timeAttackManager.currentCorrectionCost)
                }
            }
            
            // Input Text Area
            VStack {
                if timeAttackManager.isActive {
                    highlightedInputView
                } else {
                    basicInputView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Progress Indicator
            if timeAttackManager.isActive {
                progressIndicator
            }
            
            // Live Feedback
            if timeAttackManager.isActive {
                liveFeedbackBar
            }
        }
        .padding()
    }
    
    private var basicInputView: some View {
        TextEditor(text: $userInput)
            .font(.body)
            .disabled(!timeAttackManager.isActive)
            .focused($isInputFocused)
            .onChange(of: userInput) { _, newValue in
                if timeAttackManager.isActive {
                    timeAttackManager.updateInput(newValue)
                }
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
                    timeAttackManager.updateInput(newValue)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(timeAttackManager.newRecordPossible ? Color.green : Color.secondary.opacity(0.2), lineWidth: 2)
                .shadow(color: timeAttackManager.newRecordPossible ? .green : .clear, radius: 4)
        )
        .animation(.easeInOut(duration: 0.3), value: timeAttackManager.newRecordPossible)
    }
    
    private var progressIndicator: some View {
        let progress = calculateProgress()
        
        return VStack(spacing: 4) {
            HStack {
                Text("Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(progressColor(progress))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progressColor(progress).opacity(0.7), progressColor(progress)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (progress / 100.0), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    private var liveFeedbackBar: some View {
        HStack {
            Label("Accuracy: \(String(format: "%.1f%%", typingTestManager.characterAccuracy))", 
                  systemImage: "target")
            .foregroundColor(accuracyColor)
            
            Spacer()
            
            let rating = timeAttackManager.currentPerformanceRating
            if !rating.isEmpty && rating != "No data" {
                Text(rating)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Timer & Stats Panel
    
    private var timerStatsPanel: some View {
        VStack(alignment: .center, spacing: 16) {
            // Timer Display
            timerDisplay
            
            Divider()
            
            // Personal Best
            if let stats = timeAttackManager.currentStats {
                personalBestSection(stats)
            }
            
            Divider()
            
            // Current Stats
            currentStatsSection
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundColor(timerColor)
            
            Text(formattedCurrentTime)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .scaleEffect(timeAttackManager.isActive ? 1.05 : 1.0)
                .animation(timerPulseAnimation, value: timeAttackManager.isActive)
            
            Text("CURRENT TIME")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func personalBestSection(_ stats: TimeAttackStats) -> some View {
        VStack(spacing: 8) {
            Text("🏆 PERSONAL BEST")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            Text(stats.formattedPersonalBest)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.orange)
            
            if stats.hasPersonalBest,
               let estimatedTime = timeAttackManager.estimatedCompletionTime,
               estimatedTime < stats.personalBest!.completionTime {
                Text("🔥 ON TRACK FOR NEW RECORD!")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .fontWeight(.bold)
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
            }
        }
    }
    
    private var currentStatsSection: some View {
        VStack(spacing: 12) {
            if timeAttackManager.isActive {
                StatRow(
                    icon: "gearshape.fill",
                    title: "Backspaces",
                    value: "\(timeAttackManager.currentCorrectionCost)",
                    color: correctionColor
                )
                
                if let estimated = timeAttackManager.estimatedCompletionTime {
                    StatRow(
                        icon: "clock.arrow.circlepath",
                        title: "Estimated",
                        value: formatTime(estimated),
                        color: .purple
                    )
                }
                
                let progress = calculateProgress()
                StatRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress",
                    value: "\(Int(progress))%",
                    color: .blue
                )
            } else {
                Text("Ready to start")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        HStack {
            // Start/Stop Controls
            HStack(spacing: 12) {
                Button(action: {
                    startTimeAttack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Time Attack")
                        Text("⌘S")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .disabled(selectedTask == nil || timeAttackManager.isActive)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("s", modifiers: .command)
                
                Button(action: {
                    stopTimeAttack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                        Text("⌘.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .disabled(!timeAttackManager.isActive)
                .buttonStyle(.bordered)
                .keyboardShortcut(".", modifiers: .command)
                
                Button(action: {
                    forceCompleteTimeAttack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Finish")
                        Text("⌘⏎")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .disabled(!timeAttackManager.isActive || calculateProgress() < 90.0)
                .buttonStyle(.bordered)
                .keyboardShortcut(.return, modifiers: .command)
                
                Button(action: {
                    retryCurrentTask()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                        Text("⌘R")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .disabled(!timeAttackManager.isActive && selectedTask == nil)
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: .command)
            }
            
            // Hidden shortcuts for keyboard-only users
            Group {
                Button("") { stopTimeAttack() }
                    .keyboardShortcut(.escape)
                    .hidden()
                    .disabled(!timeAttackManager.isActive)
            }
            
            Spacer()
            
            // Instructions with updated shortcuts
            VStack(alignment: .trailing, spacing: 4) {
                if !timeAttackManager.isActive {
                    Text("Select a task and start your Time Attack!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Use the buttons above or keyboard shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                } else {
                    Text("Type the target text as quickly and accurately as possible!")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    HStack(spacing: 8) {
                        Text("Progress: \(Int(calculateProgress()))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if calculateProgress() >= 90.0 {
                            Text("⌘⏎ to Finish!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        } else {
                            Text("Esc to Abort")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Initialize repositories with model context
        timeAttackRepository.setModelContext(modelContext)
        
        // Setup completion handler with animation
        typingTestManager.onTimeAttackCompleted = { result in
            currentResult = result
            
            // Trigger completion animation
            withAnimation(.easeInOut(duration: 0.5)) {
                showCompletionAnimation = true
            }
            
            // Burst effect after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                    completionBurst = true
                }
            }
            
            // Show modal after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingCompletionModal = true
                showCompletionAnimation = false
                completionBurst = false
            }
        }
        
        // Select first task if available
        if selectedTask == nil && !tasks.isEmpty {
            selectedTask = tasks.first
        }
    }
    
    private func selectTask(_ task: IELTSTask) {
        if timeAttackManager.isActive {
            timeAttackManager.abortTimeAttack()
        }
        selectedTask = task
        userInput = ""
    }
    
    private func startTimeAttack() {
        guard let task = selectedTask else { return }
        
        userInput = ""
        timeAttackManager.startTimeAttack(with: task)
        
        // Focus input area
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }
    
    private func stopTimeAttack() {
        timeAttackManager.abortTimeAttack()
        userInput = ""
    }
    
    private func retryCurrentTask() {
        timeAttackManager.retryCurrentTask()
        userInput = ""
        
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }
    
    private func resetForNewTask() {
        userInput = ""
        currentResult = nil
    }
    
    // MARK: - Helper Views and Computed Properties
    
    private var formattedCurrentTime: String {
        let time = timeAttackManager.currentTime
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    private var timerColor: Color {
        if !timeAttackManager.isActive {
            return .secondary
        } else if timeAttackManager.newRecordPossible {
            return .green
        } else {
            return .orange
        }
    }
    
    // Timer pulse animation when active
    private var timerPulseAnimation: Animation? {
        timeAttackManager.isActive ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : nil
    }
    
    private var accuracyColor: Color {
        let accuracy = typingTestManager.characterAccuracy
        if accuracy >= 98 { return .green }
        else if accuracy >= 95 { return .blue }
        else if accuracy >= 90 { return .orange }
        else { return .red }
    }
    
    private var correctionColor: Color {
        let corrections = timeAttackManager.currentCorrectionCost
        if corrections == 0 { return .green }
        else if corrections <= 2 { return .blue }
        else if corrections <= 5 { return .orange }
        else { return .red }
    }
    
    private func calculateProgress() -> Double {
        guard let task = selectedTask else { return 0.0 }
        return min(100.0, Double(userInput.count) / Double(task.modelAnswer.count) * 100.0)
    }
    
    private func progressColor(_ progress: Double) -> Color {
        switch progress {
        case 0..<25: return .blue
        case 25..<50: return .orange
        case 50..<75: return .yellow
        case 75..<90: return .mint
        case 90...: return .green
        default: return .blue
        }
    }
    
    // MARK: - Completion Animation
    
    private var completionAnimationOverlay: some View {
        ZStack {
            // Background overlay
            Rectangle()
                .fill(.black.opacity(0.3))
                .ignoresSafeArea()
            
            // Completion message
            VStack(spacing: 20) {
                // Success icon with burst effect
                ZStack {
                    // Burst effect
                    if completionBurst {
                        ForEach(0..<8) { i in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 4, height: 40)
                                .offset(y: -20)
                                .rotationEffect(.degrees(Double(i) * 45))
                                .scaleEffect(completionBurst ? 1.0 : 0.1)
                        }
                    }
                    
                    // Main success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(showCompletionAnimation ? 1.0 : 0.1)
                        .rotationEffect(.degrees(showCompletionAnimation ? 0 : -180))
                }
                
                // Success message
                Text("COMPLETED!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(showCompletionAnimation ? 1.0 : 0.5)
                    .opacity(showCompletionAnimation ? 1.0 : 0.0)
                
                if let result = currentResult {
                    VStack(spacing: 8) {
                        Text("Time: \(result.formattedTime)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Accuracy: \(String(format: "%.1f%%", result.finalAccuracy))")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                        
                        if result.isPersonalBest {
                            Text("🏆 NEW PERSONAL BEST!")
                                .font(.headline)
                                .foregroundColor(.yellow)
                                .fontWeight(.bold)
                                .scaleEffect(completionBurst ? 1.1 : 1.0)
                        }
                    }
                    .scaleEffect(showCompletionAnimation ? 1.0 : 0.5)
                    .opacity(showCompletionAnimation ? 1.0 : 0.0)
                }
            }
        }
    }
    
    private func getHighlightedText() -> AttributedString {
        // Simplified highlighting - in real implementation would use BasicErrorCounter
        var attributedString = AttributedString(userInput)
        
        guard let task = selectedTask else { return attributedString }
        
        let target = task.modelAnswer
        for (index, char) in userInput.enumerated() {
            if index < target.count {
                let targetChar = target[target.index(target.startIndex, offsetBy: index)]
                let range = attributedString.index(attributedString.startIndex, offsetByCharacters: index)..<attributedString.index(attributedString.startIndex, offsetByCharacters: index + 1)
                
                if char == targetChar {
                    attributedString[range].backgroundColor = .green.opacity(0.3)
                } else {
                    attributedString[range].backgroundColor = .red.opacity(0.3)
                }
            }
        }
        
        return attributedString
    }
    
    // MARK: - Keyboard Shortcuts Helper
    
    private func forceCompleteTimeAttack() {
        // Force completion if input is at least 90% complete
        guard let task = selectedTask else { return }
        
        let progress = Double(userInput.count) / Double(task.modelAnswer.count)
        if progress >= 0.9 {
            // End immediately with current input
            if let result = typingTestManager.endTimeAttack() {
                currentResult = result
                showingCompletionModal = true
            }
        } else {
            // Show brief message that force completion requires 90% progress
            // For now, just play a sound to indicate it's not ready
            NSSound.beep()
        }
    }
    
    // MARK: - Target Text Helpers
    
    private func copyTargetText() {
        guard let task = selectedTask else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.modelAnswer, forType: .string)
    }
    
    private func selectAllTargetText() {
        // This will be handled by the textSelection binding if implemented
        // For now, we'll provide visual feedback
        NSSound(named: "Tink")?.play()
    }
}

// MARK: - Selectable Text View

struct SelectableTextView: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        // Configure text container
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.clear
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            textView.string = text
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    TimeAttackView()
        .modelContainer(for: [IELTSTask.self, TypingResult.self, TimeAttackResult.self], inMemory: true)
}