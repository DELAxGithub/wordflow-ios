//
//  TypingTestManager.swift
//  Wordflow - Typing Practice App
//

import Foundation
import Observation

// MARK: - Timer Mode (Phase A)
enum TimerMode: Codable, Identifiable, CaseIterable, Hashable {
    case exam // 固定2分
    case practice(TimeInterval) // 可変時間
    
    var id: String {
        switch self {
        case .exam:
            return "exam"
        case .practice(let duration):
            return "practice_\(Int(duration))"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .exam:
            return 120 // 2分固定
        case .practice(let duration):
            return duration
        }
    }
    
    var displayName: String {
        switch self {
        case .exam:
            return "試験モード (2分)"
        case .practice(let duration):
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            if minutes > 0 {
                return "練習モード (\(minutes)分\(seconds > 0 ? "\(seconds)秒" : ""))"
            } else {
                return "練習モード (\(seconds)秒)"
            }
        }
    }
    
    var shortName: String {
        switch self {
        case .exam:
            return "2分"
        case .practice(let duration):
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            if minutes > 0 {
                return "\(minutes)分\(seconds > 0 ? "\(seconds)秒" : "")"
            } else {
                return "\(seconds)秒"
            }
        }
    }
    
    // CaseIterable対応（デフォルトの練習モードオプション）
    static var allCases: [TimerMode] {
        return [
            .practice(10),   // 10秒 - デフォルト
            .practice(30),   // 30秒
            .practice(60),   // 1分
            .practice(90),   // 1分30秒
            .exam,           // 試験モード (2分)
            .practice(180),  // 3分
            .practice(300)   // 5分
        ]
    }
}

// MARK: - Scoring Result (Phase A)
struct ScoringResult {
    let grossWPM: Double        // 入力した単語総数 ÷ 経過時間（分）
    let netWPM: Double          // 正しく一致した単語数 ÷ 経過時間（分）
    let accuracy: Double        // 一致単語数 ÷ 目標単語数 × 100
    let qualityScore: Double    // Net WPM × Accuracy ÷ 100
    let errorBreakdown: [String: Int] // Simplified for now
    let matchedWords: Int
    let totalWords: Int
    let totalErrors: Int
    let errorRate: Double
    let completionPercentage: Double
    
    // Legacy compatibility
    var characterAccuracy: Double { accuracy }
    var basicErrorCount: Int { totalErrors }
}

// MARK: - Basic Scoring Engine (Phase A)
class BasicScoringEngine {
    func calculateScore(userInput: String, targetText: String, elapsedTime: TimeInterval) -> ScoringResult {
        let elapsedMinutes = max(0.001, elapsedTime / 60.0)
        
        // Word-based calculations for WPM
        let userWords = tokenizeWords(userInput)
        let targetWords = tokenizeWords(targetText)
        let grossWPM = Double(userWords.count) / elapsedMinutes
        
        // ✅ FIXED: Character-level accuracy calculation
        let accuracy = calculateCharacterAccuracy(userInput: userInput, targetText: targetText)
        
        // Calculate correctly typed words based on character accuracy
        let inputWordCount = userWords.count
        let correctWordRatio = accuracy / 100.0
        let estimatedCorrectWords = Double(inputWordCount) * correctWordRatio
        let netWPM = estimatedCorrectWords / elapsedMinutes
        
        // ✅ FIXED: Separate completion percentage from accuracy
        let completionPercentage = targetWords.count > 0 ? 
            min(100.0, Double(userWords.count) / Double(targetWords.count) * 100.0) : 0.0
        
        // Quality Score = Net WPM × Accuracy ÷ 100
        let qualityScore = netWPM * accuracy / 100.0
        
        // Error calculations based on character accuracy
        let totalInputChars = userInput.count
        let incorrectChars = Int(Double(totalInputChars) * (100.0 - accuracy) / 100.0)
        let errorRate = totalInputChars > 0 ? Double(incorrectChars) / Double(totalInputChars) * 100 : 0
        
        return ScoringResult(
            grossWPM: grossWPM,
            netWPM: netWPM,
            accuracy: accuracy,
            qualityScore: qualityScore,
            errorBreakdown: [:],
            matchedWords: Int(estimatedCorrectWords),
            totalWords: targetWords.count,
            totalErrors: incorrectChars,
            errorRate: errorRate,
            completionPercentage: completionPercentage
        )
    }
    
    // ✅ NEW: Proper character-level accuracy calculation
    private func calculateCharacterAccuracy(userInput: String, targetText: String) -> Double {
        // Handle empty input
        guard !userInput.isEmpty else { return 100.0 }
        
        // Normalize strings (trim whitespace, handle newlines consistently)
        let normalizedInput = normalizeText(userInput)
        let normalizedTarget = normalizeText(targetText)
        
        // Compare only the typed portion
        let comparisonLength = min(normalizedInput.count, normalizedTarget.count)
        guard comparisonLength > 0 else { return 100.0 }
        
        let inputSubstring = String(normalizedInput.prefix(comparisonLength))
        let targetSubstring = String(normalizedTarget.prefix(comparisonLength))
        
        // Character-by-character comparison
        var correctChars = 0
        for (inputChar, targetChar) in zip(inputSubstring, targetSubstring) {
            if inputChar == targetChar {
                correctChars += 1
            }
        }
        
        let accuracy = Double(correctChars) / Double(comparisonLength) * 100.0
        
        // 🔍 ENHANCED DEBUG: Detailed character-level comparison
        #if DEBUG
        print("🎯 Accuracy Debug (Enhanced):")
        print("   Raw Input length: \(userInput.count), Raw Target length: \(targetText.count)")
        print("   Normalized Input length: \(normalizedInput.count), Normalized Target length: \(normalizedTarget.count)")
        print("   Comparison length: \(comparisonLength)")
        print("   Correct chars: \(correctChars)/\(comparisonLength)")
        print("   Accuracy: \(String(format: "%.1f", accuracy))%")
        
        // Show first 20 characters with Unicode values
        print("   First 20 chars comparison:")
        for i in 0..<min(20, comparisonLength) {
            let inputChar = inputSubstring[inputSubstring.index(inputSubstring.startIndex, offsetBy: i)]
            let targetChar = targetSubstring[targetSubstring.index(targetSubstring.startIndex, offsetBy: i)]
            let match = inputChar == targetChar ? "✓" : "✗"
            let inputUnicode = inputChar.unicodeScalars.first?.value ?? 0
            let targetUnicode = targetChar.unicodeScalars.first?.value ?? 0
            print("   [\(i)] \(match) '\(inputChar)'(U+\(String(inputUnicode, radix: 16).uppercased())) vs '\(targetChar)'(U+\(String(targetUnicode, radix: 16).uppercased()))")
        }
        
        // Show summary of error types
        var errorTypes: [String: Int] = [:]
        for (inputChar, targetChar) in zip(inputSubstring, targetSubstring) {
            if inputChar != targetChar {
                let errorType = getErrorType(input: inputChar, target: targetChar)
                errorTypes[errorType, default: 0] += 1
            }
        }
        if !errorTypes.isEmpty {
            print("   Error types: \(errorTypes)")
        }
        #endif
        
        return accuracy
    }
    
    // Helper function to normalize text for comparison
    private func normalizeText(_ text: String) -> String {
        return text
            // Line ending normalization
            .replacingOccurrences(of: "\r\n", with: "\n")  // Windows line endings
            .replacingOccurrences(of: "\r", with: "\n")    // Mac classic line endings
            // Space normalization
            .replacingOccurrences(of: "\t", with: " ")     // Tab to space
            .replacingOccurrences(of: "\u{00A0}", with: " ") // Non-breaking space to space
            .replacingOccurrences(of: "\u{3000}", with: " ") // Ideographic space to space
            // Unicode normalization (decomposed → composed form)
            .precomposedStringWithCanonicalMapping
            // Remove control characters except newlines and spaces
            .filter { char in
                let unicodeScalar = char.unicodeScalars.first
                let isControlChar = unicodeScalar?.properties.generalCategory == .control
                return !isControlChar || char.isNewline || char.isWhitespace
            }
            // Trim only outer whitespace, preserve internal spacing
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Helper function to categorize error types for debugging
    private func getErrorType(input: Character, target: Character) -> String {
        let inputUnicode = input.unicodeScalars.first?.value ?? 0
        let targetUnicode = target.unicodeScalars.first?.value ?? 0
        
        if input.isWhitespace && target.isWhitespace {
            return "whitespace_mismatch"
        } else if input.isWhitespace || target.isWhitespace {
            return "whitespace_vs_char"
        } else if input.isNewline || target.isNewline {
            return "newline_mismatch"
        } else if input.lowercased() == target.lowercased() {
            return "case_difference"
        } else if abs(Int(inputUnicode) - Int(targetUnicode)) < 10 {
            return "similar_chars"
        } else {
            return "different_chars"
        }
    }
    
    private func tokenizeWords(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }
}

@MainActor
@Observable
final class TypingTestManager {
    // Test state
    private(set) var isActive: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var remainingTime: TimeInterval = 10 // Default 10 seconds
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var timerMode: TimerMode = .practice(10) // Default to 10 seconds
    
    // Phase A: Enhanced scoring system
    private let scoringEngine = BasicScoringEngine()
    private(set) var currentScore: ScoringResult = ScoringResult(
        grossWPM: 0, netWPM: 0, accuracy: 100, qualityScore: 0,
        errorBreakdown: [:], matchedWords: 0, totalWords: 0,
        totalErrors: 0, errorRate: 0, completionPercentage: 0
    )
    
    // Legacy compatibility properties
    var grossWPM: Double { currentScore.grossWPM }
    var netWPM: Double { currentScore.netWPM }
    var characterAccuracy: Double { currentScore.accuracy }
    var wordAccuracy: Double { currentScore.accuracy } // Simplified to same as character accuracy
    var completionPercentage: Double { currentScore.completionPercentage }
    var basicErrorCount: Int { currentScore.totalErrors }
    var qualityScore: Double { currentScore.qualityScore }
    
    // Performance tracking
    private var wpmHistory: [Double] = []
    private(set) var wpmVariation: Double = 0  // Consistency metric
    
    // Personal Best Records
    struct PersonalBest: Codable {
        let netWPM: Double
        let accuracy: Double
        let date: Date
        
        init(netWPM: Double, accuracy: Double) {
            self.netWPM = netWPM
            self.accuracy = accuracy
            self.date = Date()
        }
    }
    
    // Best records by timer mode
    private var personalBests: [TimerMode: PersonalBest] = [:]
    
    // Current session comparison
    private(set) var isPersonalBest: Bool = false
    
    // Backward compatibility
    var currentWPM: Double { netWPM }  // Main display uses Net WPM
    var accuracy: Double { characterAccuracy }  // Main display uses character accuracy
    
    // Current session
    private(set) var currentTask: IELTSTask?
    private(set) var userInput: String = ""
    private var timer: Timer?
    
    // Time up completion handler
    var onTimeUp: (() -> Void)?
    
    // Configuration (Phase A: 100ms updates as per requirements)
    private var timeLimit: TimeInterval { timerMode.duration }
    let updateInterval: TimeInterval = 0.1 // 100ms as per Phase A requirements
    
    init() {
        loadPersonalBests()
    }
    
    func setTimerMode(_ mode: TimerMode) {
        guard !isActive else { return } // Don't change mode during active test
        timerMode = mode
        remainingTime = timeLimit
    }
    
    // Phase A: Custom practice mode duration setter
    func setPracticeModeDuration(_ duration: TimeInterval) {
        guard !isActive else { return }
        timerMode = .practice(duration)
        remainingTime = timeLimit
    }
    
    func startTest(with task: IELTSTask) {
        currentTask = task
        isActive = true
        isPaused = false
        remainingTime = timeLimit
        elapsedTime = 0
        userInput = ""
        resetMetrics()
        
        task.markAsUsed()
        startTimer()
    }
    
    func updateInput(_ input: String) {
        guard isActive && !isPaused else { return }
        
        userInput = input
        calculateMetrics()
    }
    
    func pauseTest() {
        guard isActive && !isPaused else { return }
        isPaused = true
        timer?.invalidate()
    }
    
    func resumeTest() {
        guard isActive && isPaused else { return }
        isPaused = false
        startTimer()
    }
    
    func endTest() -> TypingResult? {
        guard let task = currentTask else { return nil }
        
        isActive = false
        isPaused = false
        timer?.invalidate()
        
        calculateFinalMetrics()
        
        // Phase A: Use enhanced initializer with scoring result
        let result = TypingResult(
            task: task,
            userInput: userInput,
            duration: elapsedTime,
            scoringResult: currentScore,
            timerMode: timerMode
        )
        
        reset()
        return result
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateTimer()
            }
        }
    }
    
    private func updateTimer() {
        guard isActive && !isPaused else { return }
        
        elapsedTime += updateInterval
        remainingTime = max(0, timeLimit - elapsedTime)
        
        calculateMetrics()
        
        if remainingTime <= 0 {
            onTimeUp?()
        }
    }
    
    // Phase A: Legacy methods removed - now handled by ScoringEngine
    
    private func calculateMetrics() {
        guard let task = currentTask else { return }
        
        // Phase A: Use new scoring engine
        currentScore = scoringEngine.calculateScore(
            userInput: userInput,
            targetText: task.modelAnswer,
            elapsedTime: elapsedTime
        )
        
        // Track WPM history for consistency calculation (using new netWPM)
        wpmHistory.append(currentScore.netWPM)
        if wpmHistory.count > 10 { // Keep last 10 measurements
            wpmHistory.removeFirst()
        }
        
        // Calculate WPM variation (consistency metric)
        if wpmHistory.count >= 3 {
            wpmVariation = calculateWPMVariation()
        }
    }
    
    private func calculateWPMVariation() -> Double {
        guard wpmHistory.count >= 3 else { return 0 }
        
        let mean = wpmHistory.reduce(0, +) / Double(wpmHistory.count)
        if mean == 0 { return 0 }
        
        let variance = wpmHistory.reduce(0) { sum, wpm in
            sum + pow(wpm - mean, 2)
        } / Double(wpmHistory.count)
        
        let standardDeviation = sqrt(variance)
        return (standardDeviation / mean) * 100  // Coefficient of variation as percentage
    }
    
    private func calculateFinalMetrics() {
        calculateMetrics()
        checkAndUpdatePersonalBest()
    }
    
    private func checkAndUpdatePersonalBest() {
        let currentNetWPM = currentScore.netWPM
        let currentAccuracy = currentScore.accuracy
        
        // Only consider as personal best if accuracy is above 90%
        guard currentAccuracy >= 90 else {
            isPersonalBest = false
            return
        }
        
        // Phase A: Use timer mode ID for key (to handle practice modes with different durations)
        let _ = timerMode.id // For future enhancement
        
        if let existingBest = personalBests[timerMode] {
            if currentNetWPM > existingBest.netWPM {
                personalBests[timerMode] = PersonalBest(netWPM: currentNetWPM, accuracy: currentAccuracy)
                isPersonalBest = true
                savePersonalBests()
            } else {
                isPersonalBest = false
            }
        } else {
            personalBests[timerMode] = PersonalBest(netWPM: currentNetWPM, accuracy: currentAccuracy)
            isPersonalBest = true
            savePersonalBests()
        }
    }
    
    func getPersonalBest(for mode: TimerMode) -> PersonalBest? {
        return personalBests[mode]
    }
    
    // UserDefaults persistence (Phase A: Updated for new timer modes)
    private func savePersonalBests() {
        let encoder = JSONEncoder()
        for (mode, best) in personalBests {
            let key = "PersonalBest_\(mode.id)" // Use timer mode ID
            if let data = try? encoder.encode(best) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    private func loadPersonalBests() {
        let decoder = JSONDecoder()
        for mode in TimerMode.allCases {
            let key = "PersonalBest_\(mode.id)" // Use timer mode ID
            if let data = UserDefaults.standard.data(forKey: key),
               let best = try? decoder.decode(PersonalBest.self, from: data) {
                personalBests[mode] = best
            }
        }
    }
    
    private func resetMetrics() {
        // Phase A: Reset to default scoring result
        currentScore = ScoringResult(
            grossWPM: 0, netWPM: 0, accuracy: 100, qualityScore: 0,
            errorBreakdown: [:], matchedWords: 0, totalWords: 0,
            totalErrors: 0, errorRate: 0, completionPercentage: 0
        )
        wpmHistory.removeAll()
        wpmVariation = 0
    }
    
    private func reset() {
        currentTask = nil
        userInput = ""
        resetMetrics()
    }
}