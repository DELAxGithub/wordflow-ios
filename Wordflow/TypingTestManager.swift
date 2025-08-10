//
//  TypingTestManager.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import Observation
import QuartzCore

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
            .exam,
            .practice(30),   // 30秒
            .practice(60),   // 1分
            .practice(90),   // 1分30秒
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
        
        // Simple word-based calculation
        let userWords = tokenizeWords(userInput)
        let targetWords = tokenizeWords(targetText)
        
        let grossWPM = Double(userWords.count) / elapsedMinutes
        
        // Simple matching for MVP
        let matchedWords = min(userWords.count, targetWords.count)
        let netWPM = Double(matchedWords) / elapsedMinutes
        let accuracy = targetWords.count > 0 ? Double(matchedWords) / Double(targetWords.count) * 100 : 100
        let qualityScore = netWPM * accuracy / 100.0
        let completionPercentage = targetWords.count > 0 ? 
            min(100.0, Double(userWords.count) / Double(targetWords.count) * 100.0) : 0.0
        
        let totalErrors = max(0, userWords.count - matchedWords)
        let errorRate = userWords.count > 0 ? Double(totalErrors) / Double(userWords.count) * 100 : 0
        
        return ScoringResult(
            grossWPM: grossWPM,
            netWPM: netWPM,
            accuracy: accuracy,
            qualityScore: qualityScore,
            errorBreakdown: [:],
            matchedWords: matchedWords,
            totalWords: targetWords.count,
            totalErrors: totalErrors,
            errorRate: errorRate,
            completionPercentage: completionPercentage
        )
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
    private(set) var remainingTime: TimeInterval = 120 // Default 2 minutes
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var timerMode: TimerMode = .exam // Phase A: Default to exam mode
    
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
        let modeKey = timerMode.id
        
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