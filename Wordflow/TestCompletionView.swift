//
//  TestCompletionView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI

struct TestCompletionView: View {
    let result: TypingResult
    let timerMode: TimerMode
    let resultRepository: TypingResultRepository?
    let onRetry: () -> Void
    let onNewTask: () -> Void
    let onClose: () -> Void
    
    // 前回記録とベスト記録
    @State private var previousResult: TypingResult?
    @State private var bestResult: TypingResult?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Time Up!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Test completed in \(timerMode.displayName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Results
            VStack(spacing: 16) {
                Text("Your Results")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Phase A: Enhanced results display
                HStack(spacing: 30) {
                    ResultMetricView(
                        title: "Net WPM",
                        value: String(format: "%.0f", result.netWPM),
                        icon: "speedometer",
                        color: .green
                    )
                    
                    ResultMetricView(
                        title: "Quality Score",
                        value: String(format: "%.0f", result.qualityScore),
                        icon: "star.fill",
                        color: .blue
                    )
                    
                    ResultMetricView(
                        title: "Accuracy",
                        value: String(format: "%.0f%%", result.accuracy),
                        icon: "target",
                        color: .orange
                    )
                    
                    ResultMetricView(
                        title: "Gross WPM",
                        value: String(format: "%.0f", result.grossWPM),
                        icon: "keyboard",
                        color: .gray
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // 前回記録とベスト記録セクション
            if previousResult != nil || bestResult != nil {
                VStack(spacing: 16) {
                    Text("Today's Records")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 20) {
                        // 前回記録
                        if let previous = previousResult {
                            VStack(spacing: 8) {
                                Text("Previous")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 15) {
                                    ComparisonMetricView(
                                        title: "WPM",
                                        current: result.netWPM,
                                        previous: previous.netWPM,
                                        icon: "speedometer"
                                    )
                                    
                                    ComparisonMetricView(
                                        title: "Accuracy",
                                        current: result.accuracy,
                                        previous: previous.accuracy,
                                        icon: "target",
                                        isPercentage: true
                                    )
                                }
                            }
                        }
                        
                        // ベスト記録
                        if let best = bestResult {
                            VStack(spacing: 8) {
                                Text("Today's Best")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 15) {
                                    ComparisonMetricView(
                                        title: "WPM",
                                        current: result.netWPM,
                                        previous: best.netWPM,
                                        icon: "crown.fill",
                                        isBest: true
                                    )
                                    
                                    ComparisonMetricView(
                                        title: "Accuracy",
                                        current: result.accuracy,
                                        previous: best.accuracy,
                                        icon: "star.fill",
                                        isPercentage: true,
                                        isBest: true
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Detailed Results Section
            VStack(spacing: 12) {
                Text("Detailed Results")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Input:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getHighlightedText())
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Expected:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(result.targetText.prefix(result.userInput.count))
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Phase A: Error breakdown display
                        Text("Error Analysis:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getErrorBreakdownText())
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: 150)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Try Again (⌘R)", systemImage: "arrow.clockwise") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("New Task", systemImage: "doc.text") {
                    onNewTask()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Close", systemImage: "xmark") {
                    onClose()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 600, height: 700)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 20)
        .onAppear {
            // Set focus to enable keyboard input
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Focus is handled automatically
            }
            
            // Load previous and best records data
            loadRecordsData()
        }
        .background(
            // Hidden button to capture Cmd+R key
            Button("") {
                onRetry()
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0)
        )
    }
    
    // MARK: - Helper Functions
    
    private func loadRecordsData() {
        guard let repository = resultRepository else { return }
        
        // 前回記録を取得
        previousResult = repository.getPreviousResultForTimerMode(timerMode, excluding: result)
        
        // ベスト記録を取得
        bestResult = repository.getBestResultForTimerMode(timerMode)
    }
    
    private func getHighlightedText() -> AttributedString {
        // Phase A: Use basic error counter for highlighting
        let errorCounter = BasicErrorCounter()
        let errorInfo = errorCounter.countBasicErrors(input: result.userInput, target: result.targetText)
        var attributedString = AttributedString(result.userInput)
        
        // Apply basic highlighting based on error positions
        for (index, _) in result.userInput.enumerated() {
            if errorInfo.errorPositions.contains(index) {
                if let range = attributedString.range(of: String(result.userInput[result.userInput.index(result.userInput.startIndex, offsetBy: index)])) {
                    attributedString[range].backgroundColor = .red.opacity(0.3)
                    attributedString[range].foregroundColor = .primary
                }
            } else {
                if let range = attributedString.range(of: String(result.userInput[result.userInput.index(result.userInput.startIndex, offsetBy: index)])) {
                    attributedString[range].backgroundColor = .green.opacity(0.3)
                    attributedString[range].foregroundColor = .primary
                }
            }
        }
        
        return attributedString
    }
    
    // Phase A: Error breakdown display helper (simplified)
    private func getErrorBreakdownText() -> String {
        if result.basicErrorCount == 0 {
            return "Perfect!"
        } else {
            return "Total Errors: \(result.basicErrorCount)"
        }
    }
}

struct ResultMetricView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        
        TestCompletionView(
            result: TypingResult(
                task: IELTSTask(
                    taskType: .task2,
                    topic: "Sample Topic",
                    modelAnswer: "Sample answer",
                    targetBandScore: 7.0
                ),
                userInput: "Sample input",
                duration: 120,
                wpm: 45,
                accuracy: 92,
                completion: 85,
                errors: 5
            ),
            timerMode: .exam,
            resultRepository: nil,
            onRetry: {},
            onNewTask: {},
            onClose: {}
        )
    }
}