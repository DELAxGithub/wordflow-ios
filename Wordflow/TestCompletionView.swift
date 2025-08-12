//
//  TestCompletionView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI
import AppKit

struct TestCompletionView: View {
    let result: TypingResult
    let timerMode: TimerMode
    let resultRepository: TypingResultRepository?
    let testManager: TypingTestManager // 🔧 FIX: Add testManager to access personal bests
    let onRetry: () -> Void
    let onNewTask: () -> Void
    let onClose: () -> Void
    
    // 前回記録とベスト記録
    @State private var previousResult: TypingResult?
    @State private var bestResult: TypingResult?
    @State private var personalBest: TypingTestManager.PersonalBest? // 🔧 FIX: Add personal best from test manager
    
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
            
            // 前回記録とベスト記録セクション（🔧 FIX: Include personal best from test manager）
            if previousResult != nil || bestResult != nil || personalBest != nil {
                VStack(spacing: 16) {
                    HStack {
                        Text("Records")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // 🏆 NEW PERSONAL BEST indicator
                        if testManager.isPersonalBest {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.orange)
                                Text("NEW BEST!")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
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
                        
                        // 🔧 FIX: Personal Best from TestManager (more reliable)
                        if let personalBest = personalBest {
                            VStack(spacing: 8) {
                                Text("Personal Best")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 15) {
                                    ComparisonMetricView(
                                        title: "WPM",
                                        current: result.netWPM,
                                        previous: personalBest.netWPM,
                                        icon: "crown.fill",
                                        isBest: true
                                    )
                                    
                                    ComparisonMetricView(
                                        title: "Accuracy",
                                        current: result.accuracy,
                                        previous: personalBest.accuracy,
                                        icon: "star.fill",
                                        isPercentage: true,
                                        isBest: true
                                    )
                                }
                            }
                        } else if let best = bestResult {
                            // Fallback to repository best if personal best not available
                            VStack(spacing: 8) {
                                Text("Best Record")
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
            VStack(spacing: 12) {
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
                
                // JSON Telemetry Buttons - Enhanced visibility
                VStack(spacing: 8) {
                    Divider()
                    
                    Text("JSON Telemetry Export")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("📊 Export JSON Data", systemImage: "doc.text.fill") {
                            exportCurrentResult()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .help("Export this test result as JSON telemetry data")
                        
                        Button("📁 Open Telemetry Folder", systemImage: "folder.fill") {
                            openTelemetryFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Open the folder containing all JSON typing metrics")
                    }
                }
                
                // Version Info - Bottom right corner
                HStack {
                    Spacer()
                    Text("Wordflow v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                .padding(.top, 8)
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
        
        // ベスト記録を取得（repositoryから）
        bestResult = repository.getBestResultForTimerMode(timerMode)
        
        // 🔧 FIX: Get personal best from test manager (more reliable and up-to-date)
        personalBest = testManager.getPersonalBest(for: timerMode)
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
    
    // MARK: - Telemetry Methods
    
    /// Open the telemetry folder in Finder
    private func openTelemetryFolder() {
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access Documents directory")
            showTelemetryAlert(message: "Could not access Documents directory")
            return
        }
        
        let telemetryURL = documentsURL.appendingPathComponent("WordflowTelemetry")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: telemetryURL.path) {
            do {
                try fileManager.createDirectory(at: telemetryURL, withIntermediateDirectories: true)
                print("📁 Created telemetry directory: \(telemetryURL.path)")
            } catch {
                print("⚠️ Failed to create telemetry directory: \(error)")
                showTelemetryAlert(message: "Could not create telemetry directory")
                return
            }
        }
        
        // Open in Finder
        NSWorkspace.shared.open(telemetryURL)
        print("📂 Opened telemetry folder: \(telemetryURL.path)")
    }
    
    /// Export current result as JSON telemetry
    private func exportCurrentResult() {
        // Create telemetry JSON for this specific result
        let taskType = result.task?.taskType.rawValue ?? "unknown"
        let taskTopic = result.task?.topic ?? "unknown"
        
        // 🔧 SANITY CHECKS: 完了結果バリデーション
        let netFormula = result.grossWPM * (result.accuracy / 100.0)
        let formulaDeviation = abs(result.netWPM - netFormula) / max(result.netWPM, 0.01)
        let formulaValid = formulaDeviation <= 0.03
        let durationValid = result.testDuration >= 10.0  // 完了済みは緩い基準
        
        if !formulaValid {
            showTelemetryAlert(message: "🚨 数式バリデーション失敗\n\nGross×Accuracy≠Net WPMの整合性エラー\n偏差: \(String(format: "%.3f", formulaDeviation))")
            return
        }
        
        // 🔧 SCHEMA v1.1: 完了結果用JSONスキーマ
        let telemetryData: [String: Any] = [
            "run_id": UUID().uuidString,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "mode": "normal",  // TestCompletionは通常normalモード
            "experiment_mode": "standard",
            "task_topic": taskTopic,
            "duration_sec": result.testDuration,
            "chars_ref": result.targetText.count,
            "chars_typed": result.userInput.count,
            "unfixed_errors": result.basicErrorCount,
            "gross_wpm": result.grossWPM,
            "char_accuracy": result.accuracy,
            "net_wpm": result.netWPM,
            "keystrokes_total": 0,  // TypingResult doesn't track keystrokes
            "backspace_count": 0,   // TypingResult doesn't track backspaces
            "kspc": 1.0,            // TypingResult doesn't track KSPC
            "backspace_rate": 0.0,  // TypingResult doesn't track backspace rate
            "formula_valid": formulaValid,
            "formula_deviation": formulaDeviation,
            "app_version": "1.1",
            "device_info": getDeviceInfo()
        ]
        
        // Convert to JSON and save
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: telemetryData, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                saveCompletedResultToFile(jsonString)
            }
        } catch {
            print("⚠️ Failed to create result telemetry JSON: \(error)")
            showTelemetryAlert(message: "Failed to create telemetry data: \(error.localizedDescription)")
        }
    }
    
    private func saveCompletedResultToFile(_ jsonString: String) {
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
            // タスク情報は不要（ファイル名に統一命名を使用）
            let filename = "wordflow_v1.1_normal_completed_\(formatter.string(from: Date())).json"
            let fileURL = telemetryURL.appendingPathComponent(filename)
            
            // Write JSON to file
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📁 Completed result telemetry saved: \(fileURL.path)")
            
            // Show success
            showTelemetryAlert(message: "JSON telemetry for this result exported successfully!\n\nFile: \(filename)\nLocation: ~/Documents/WordflowTelemetry/\n\nNet WPM: \(String(format: "%.1f", result.netWPM))\nAccuracy: \(String(format: "%.1f%%", result.accuracy))")
            
        } catch {
            print("⚠️ Failed to save result telemetry file: \(error)")
            showTelemetryAlert(message: "Failed to save telemetry file: \(error.localizedDescription)")
        }
    }
    
    /// Show alert with telemetry information
    private func showTelemetryAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "JSON Telemetry"
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
            testManager: TypingTestManager(), // 🔧 FIX: Add test manager for preview
            onRetry: {},
            onNewTask: {},
            onClose: {}
        )
    }
}