//
//  TypingTestManager.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import Observation

enum TimerMode: CaseIterable, Identifiable {
    case thirtySeconds
    case twoMinutes
    
    var id: Self { self }
    
    var duration: TimeInterval {
        switch self {
        case .thirtySeconds:
            return 30
        case .twoMinutes:
            return 120
        }
    }
    
    var displayName: String {
        switch self {
        case .thirtySeconds:
            return "30 seconds"
        case .twoMinutes:
            return "2 minutes"
        }
    }
    
    var shortName: String {
        switch self {
        case .thirtySeconds:
            return "30s"
        case .twoMinutes:
            return "2m"
        }
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
    private(set) var timerMode: TimerMode = .twoMinutes
    
    // Metrics (enhanced for typing speed improvement)
    private(set) var grossWPM: Double = 0    // Total typing speed (before corrections)
    private(set) var netWPM: Double = 0      // Accurate typing speed (after corrections)
    private(set) var characterAccuracy: Double = 100  // Character-level accuracy
    private(set) var wordAccuracy: Double = 100       // Word-level accuracy
    private(set) var completionPercentage: Double = 0
    private(set) var basicErrorCount: Int = 0
    
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
    
    // Configuration (relaxed)
    private var timeLimit: TimeInterval { timerMode.duration }
    let updateInterval: TimeInterval = 0.2 // 200ms (relaxed from 100ms)
    
    init() {
        loadPersonalBests()
    }
    
    func setTimerMode(_ mode: TimerMode) {
        guard !isActive else { return } // Don't change mode during active test
        timerMode = mode
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
        
        let result = TypingResult(
            task: task,
            userInput: userInput,
            duration: elapsedTime,
            wpm: netWPM,  // Use Net WPM as main metric
            accuracy: characterAccuracy,
            completion: completionPercentage,
            errors: basicErrorCount
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
    
    // Improved: Actual word count-based WPM calculation
    private func calculateGrossWPM() -> Double {
        let words = countWords(in: userInput)
        let minutes = elapsedTime / 60.0
        return minutes > 0 ? words / minutes : 0
    }
    
    private func calculateNetWPM() -> Double {
        guard let task = currentTask else { return 0 }
        
        let correctCharacters = countCorrectCharacters()
        let words = Double(correctCharacters) / 5.0  // Standard: 5 characters = 1 word
        let minutes = elapsedTime / 60.0
        return minutes > 0 ? words / minutes : 0
    }
    
    private func countWords(in text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return Double(words.count)
    }
    
    private func countCorrectCharacters() -> Int {
        guard let task = currentTask else { return 0 }
        
        let target = task.modelAnswer
        let minLength = min(userInput.count, target.count)
        var correctChars = 0
        
        for i in 0..<minLength {
            let userIndex = userInput.index(userInput.startIndex, offsetBy: i)
            let targetIndex = target.index(target.startIndex, offsetBy: i)
            
            if userInput[userIndex] == target[targetIndex] {
                correctChars += 1
            }
        }
        
        return correctChars
    }
    
    // Enhanced: Character-level accuracy calculation
    private func calculateCharacterAccuracy() -> Double {
        guard let task = currentTask, !userInput.isEmpty else { return 100 }
        
        let correctChars = countCorrectCharacters()
        return (Double(correctChars) / Double(userInput.count)) * 100
    }
    
    // New: Word-level accuracy calculation
    private func calculateWordAccuracy() -> Double {
        guard let task = currentTask, !userInput.isEmpty else { return 100 }
        
        let userWords = getWords(from: userInput)
        let targetWords = getWords(from: task.modelAnswer)
        
        let minWordCount = min(userWords.count, targetWords.count)
        if minWordCount == 0 { return 100 }
        
        var correctWords = 0
        for i in 0..<minWordCount {
            if userWords[i] == targetWords[i] {
                correctWords += 1
            }
        }
        
        return (Double(correctWords) / Double(userWords.count)) * 100
    }
    
    private func getWords(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func calculateMetrics() {
        grossWPM = calculateGrossWPM()
        netWPM = calculateNetWPM()
        characterAccuracy = calculateCharacterAccuracy()
        wordAccuracy = calculateWordAccuracy()
        
        // Track WPM history for consistency calculation
        wpmHistory.append(netWPM)
        if wpmHistory.count > 10 { // Keep last 10 measurements
            wpmHistory.removeFirst()
        }
        
        // Calculate WPM variation (consistency metric)
        if wpmHistory.count >= 3 {
            wpmVariation = calculateWPMVariation()
        }
        
        if let task = currentTask {
            completionPercentage = min(100, (Double(userInput.count) / Double(task.modelAnswer.count)) * 100)
            basicErrorCount = max(0, userInput.count - Int(characterAccuracy / 100 * Double(userInput.count)))
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
        let currentScore = netWPM
        
        // Only consider as personal best if accuracy is above 90%
        guard characterAccuracy >= 90 else {
            isPersonalBest = false
            return
        }
        
        if let existingBest = personalBests[timerMode] {
            if currentScore > existingBest.netWPM {
                personalBests[timerMode] = PersonalBest(netWPM: currentScore, accuracy: characterAccuracy)
                isPersonalBest = true
                savePersonalBests()
            } else {
                isPersonalBest = false
            }
        } else {
            personalBests[timerMode] = PersonalBest(netWPM: currentScore, accuracy: characterAccuracy)
            isPersonalBest = true
            savePersonalBests()
        }
    }
    
    func getPersonalBest(for mode: TimerMode) -> PersonalBest? {
        return personalBests[mode]
    }
    
    // UserDefaults persistence
    private func savePersonalBests() {
        let encoder = JSONEncoder()
        for (mode, best) in personalBests {
            let key = "PersonalBest_\(mode)"
            if let data = try? encoder.encode(best) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    private func loadPersonalBests() {
        let decoder = JSONDecoder()
        for mode in TimerMode.allCases {
            let key = "PersonalBest_\(mode)"
            if let data = UserDefaults.standard.data(forKey: key),
               let best = try? decoder.decode(PersonalBest.self, from: data) {
                personalBests[mode] = best
            }
        }
    }
    
    private func resetMetrics() {
        grossWPM = 0
        netWPM = 0
        characterAccuracy = 100
        wordAccuracy = 100
        completionPercentage = 0
        basicErrorCount = 0
        wpmHistory.removeAll()
        wpmVariation = 0
    }
    
    private func reset() {
        currentTask = nil
        userInput = ""
        resetMetrics()
    }
}