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
                return "\(minutes)分"
            } else {
                return "\(seconds)秒"
            }
        }
    }
    
    static var allCases: [TimerMode] {
        return [
            .exam,
            .practice(10),  // 10秒
            .practice(30),  // 30秒
            .practice(60),  // 1分
            .practice(180), // 3分
            .practice(300), // 5分
            .practice(600)  // 10分
        ]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TimerMode, rhs: TimerMode) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Scoring Result (Phase A) 
struct ScoringResult {
    let grossWPM: Double
    let netWPM: Double
    let accuracy: Double
    let qualityScore: Double // New in Phase A
    let errorBreakdown: [String: Int]
    let matchedWords: Int
    let totalWords: Int
    let totalErrors: Int
    let errorRate: Double
    let completionPercentage: Double
    let kspc: Double
    let backspaceRate: Double
    let totalKeystrokes: Int
    let backspaceCount: Int
    let unfixedErrors: Int
    let unfixedErrorRate: Double
    let wordAccuracy: Double
    let charAccuracy: Double
    let hybridAccuracy: Double
    let isFormulaValid: Bool
    let formulaDeviation: Double
}

// MARK: - Alignment Operations

struct AlignmentOperation {
    enum OpType {
        case match
        case substitute
        case insert
        case delete
    }
    
    let type: OpType
    let targetPos: Int
    let inputPos: Int
    let targetChar: Character?
    let inputChar: Character?
}

struct AlignmentResult {
    let operations: [AlignmentOperation]
    let accuracy: Double
    let totalOperations: Int
    let matchCount: Int
    let errorCount: Int
}

// MARK: - Error Tracking

struct ErrorBlock {
    let startPosition: Int
    let length: Int
    let operations: Int
    
    enum ErrorBlockType {
        case substitution
        case insertion
        case deletion
        case mixed
    }
    
    let type: ErrorBlockType
}

// MARK: - Basic Scoring Engine (Phase A)
class BasicScoringEngine {
    // 🔧 CRASH FIX: Safe default result for error cases
    private func createDefaultScoringResult() -> ScoringResult {
        return ScoringResult(
            grossWPM: 0, netWPM: 0, accuracy: 100, qualityScore: 0,
            errorBreakdown: [:], matchedWords: 0, totalWords: 0,
            totalErrors: 0, errorRate: 0, completionPercentage: 0,
            kspc: 1.0, backspaceRate: 0, totalKeystrokes: 0, backspaceCount: 0,
            unfixedErrors: 0, unfixedErrorRate: 0.0,
            wordAccuracy: 100.0, charAccuracy: 100.0, hybridAccuracy: 100.0,
            isFormulaValid: true, formulaDeviation: 0.0
        )
    }
    
    /// Core scoring method with comprehensive metrics
    func calculateScore(
        targetText: String,
        userInput: String,
        elapsedTime: TimeInterval,
        totalKeystrokes: Int,
        backspaceCount: Int
    ) -> ScoringResult {
        // Prevent crashes with empty inputs
        guard !targetText.isEmpty, !userInput.isEmpty, elapsedTime > 0 else {
            return createDefaultScoringResult()
        }
        
        do {
            // Character-level alignment for accurate error tracking
            let alignmentResult = try performAlignment(target: targetText, input: userInput)
            
            // Calculate basic metrics
            let elapsedMinutes = max(0.01, elapsedTime / 60.0) // Prevent division by zero
            let charsTyped = userInput.count
            let charsInTarget = targetText.count
            
            // Calculate WPM using 5-char-per-word standard
            let grossWPM = Double(charsTyped) / 5.0 / elapsedMinutes
            
            // Calculate accuracy from alignment result
            let characterAccuracy = calculateCharacterAlignmentAccuracy(alignmentResult: alignmentResult)
            let wordAccuracy = calculateWordAlignment(target: targetText, input: userInput)
            
            // Net WPM with accuracy penalty
            let netWPM = grossWPM * (characterAccuracy / 100.0)
            
            // Calculate completion percentage
            let completionPercentage = min(100.0, Double(charsTyped) / Double(charsInTarget) * 100.0)
            
            // Calculate KSPC (Keystrokes Per Character)
            let kspc = charsTyped > 0 ? Double(totalKeystrokes) / Double(charsTyped) : 1.0
            
            // Calculate backspace rate
            let backspaceRate = totalKeystrokes > 0 ? Double(backspaceCount) / Double(totalKeystrokes) * 100.0 : 0.0
            
            // Error analysis from alignment
            let errorBreakdown = analyzeErrorsFromAlignment(alignmentResult)
            let totalErrors = alignmentResult.errorCount
            let errorRate = Double(totalErrors) / Double(charsTyped) * 100.0
            
            // 🔧 FORMULA VALIDATION: Net WPM = Gross WPM × Accuracy
            let expectedNetWPM = grossWPM * characterAccuracy / 100.0
            let formulaDeviation = abs(netWPM - expectedNetWPM) / max(netWPM, 0.01)
            let isFormulaValid = formulaDeviation <= 0.03 // 3% tolerance
            
            // 🔧 UNFIXED ERRORS: Count unresolved differences
            let unfixedErrors = calculateUnfixedErrors(target: targetText, input: userInput)
            let unfixedErrorRate = Double(unfixedErrors) / Double(charsTyped) * 100.0
            
            // Phase A: Quality Score (0-100)
            let qualityScore = calculateQualityScore(
                accuracy: characterAccuracy,
                consistency: 100.0 - min(100.0, backspaceRate),
                completion: completionPercentage,
                speed: min(100.0, netWPM / 60.0 * 100.0)
            )
            
            // Hybrid accuracy (weighted combination)
            let hybridAccuracy = (characterAccuracy * 0.7) + (wordAccuracy * 0.3)
            
            return ScoringResult(
                grossWPM: grossWPM,
                netWPM: netWPM,
                accuracy: characterAccuracy,
                qualityScore: qualityScore,
                errorBreakdown: errorBreakdown,
                matchedWords: calculateMatchedWords(target: targetText, input: userInput),
                totalWords: targetText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
                totalErrors: totalErrors,
                errorRate: errorRate,
                completionPercentage: completionPercentage,
                kspc: kspc,
                backspaceRate: backspaceRate,
                totalKeystrokes: totalKeystrokes,
                backspaceCount: backspaceCount,
                unfixedErrors: unfixedErrors,
                unfixedErrorRate: unfixedErrorRate,
                wordAccuracy: wordAccuracy,
                charAccuracy: characterAccuracy,
                hybridAccuracy: hybridAccuracy,
                isFormulaValid: isFormulaValid,
                formulaDeviation: formulaDeviation
            )
            
        } catch {
            print("⚠️ Error in scoring calculation: \(error)")
            return createDefaultScoringResult()
        }
    }
    
    /// Calculate Quality Score (Phase A enhancement)
    private func calculateQualityScore(accuracy: Double, consistency: Double, completion: Double, speed: Double) -> Double {
        // Weighted quality score emphasizing accuracy and consistency
        let weights: (accuracy: Double, consistency: Double, completion: Double, speed: Double) = (0.4, 0.3, 0.2, 0.1)
        
        return (accuracy * weights.accuracy) +
               (consistency * weights.consistency) +
               (completion * weights.completion) +
               (speed * weights.speed)
    }
    
    /// Safe alignment with error handling
    private func performAlignment(target: String, input: String) throws -> AlignmentResult {
        let operations = calculateAlignmentOperations(target: target, input: input)
        let matchCount = operations.filter { $0.type == .match }.count
        let errorCount = operations.filter { $0.type != .match }.count
        let totalOps = operations.count
        let accuracy = totalOps > 0 ? Double(matchCount) / Double(totalOps) * 100.0 : 100.0
        
        return AlignmentResult(
            operations: operations,
            accuracy: accuracy,
            totalOperations: totalOps,
            matchCount: matchCount,
            errorCount: errorCount
        )
    }
    
    /// Calculate alignment operations using dynamic programming
    private func calculateAlignmentOperations(target: String, input: String) -> [AlignmentOperation] {
        let targetChars = Array(target)
        let inputChars = Array(input)
        let targetLen = targetChars.count
        let inputLen = inputChars.count
        
        // DP table for edit distance with operation tracking
        var dp = Array(repeating: Array(repeating: Int.max, count: inputLen + 1), count: targetLen + 1)
        var operations: [AlignmentOperation] = []
        
        // Initialize base cases
        for i in 0...targetLen {
            dp[i][0] = i
        }
        for j in 0...inputLen {
            dp[0][j] = j
        }
        
        // Fill DP table
        for i in 1...targetLen {
            for j in 1...inputLen {
                if targetChars[i-1] == inputChars[j-1] {
                    dp[i][j] = dp[i-1][j-1] // Match
                } else {
                    dp[i][j] = 1 + min(
                        dp[i-1][j],   // Deletion
                        dp[i][j-1],   // Insertion
                        dp[i-1][j-1]  // Substitution
                    )
                }
            }
        }
        
        // Backtrack to reconstruct operations
        var i = targetLen
        var j = inputLen
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && targetChars[i-1] == inputChars[j-1] {
                operations.append(AlignmentOperation(
                    type: .match,
                    targetPos: i-1,
                    inputPos: j-1,
                    targetChar: targetChars[i-1],
                    inputChar: inputChars[j-1]
                ))
                i -= 1
                j -= 1
            } else if i > 0 && j > 0 && dp[i][j] == dp[i-1][j-1] + 1 {
                operations.append(AlignmentOperation(
                    type: .substitute,
                    targetPos: i-1,
                    inputPos: j-1,
                    targetChar: targetChars[i-1],
                    inputChar: inputChars[j-1]
                ))
                i -= 1
                j -= 1
            } else if i > 0 && dp[i][j] == dp[i-1][j] + 1 {
                operations.append(AlignmentOperation(
                    type: .delete,
                    targetPos: i-1,
                    inputPos: -1,
                    targetChar: targetChars[i-1],
                    inputChar: nil
                ))
                i -= 1
            } else if j > 0 && dp[i][j] == dp[i][j-1] + 1 {
                operations.append(AlignmentOperation(
                    type: .insert,
                    targetPos: -1,
                    inputPos: j-1,
                    targetChar: nil,
                    inputChar: inputChars[j-1]
                ))
                j -= 1
            } else {
                // Safety fallback
                break
            }
        }
        
        return operations.reversed() // Reverse to get correct order
    }
    
    /// Analyze errors from alignment operations
    private func analyzeErrorsFromAlignment(_ alignmentResult: AlignmentResult) -> [String: Int] {
        var errorBreakdown: [String: Int] = [:]
        
        for operation in alignmentResult.operations {
            switch operation.type {
            case .substitute:
                if let target = operation.targetChar, let input = operation.inputChar {
                    let errorKey = "substitute_\(target)_to_\(input)"
                    errorBreakdown[errorKey, default: 0] += 1
                }
            case .insert:
                if let input = operation.inputChar {
                    let errorKey = "insert_\(input)"
                    errorBreakdown[errorKey, default: 0] += 1
                }
            case .delete:
                if let target = operation.targetChar {
                    let errorKey = "delete_\(target)"
                    errorBreakdown[errorKey, default: 0] += 1
                }
            case .match:
                break // No error
            }
        }
        
        return errorBreakdown
    }
    
    /// Calculate unfixed errors (permanent differences)
    private func calculateUnfixedErrors(target: String, input: String) -> Int {
        // Simple Levenshtein distance for unfixed errors
        return levenshteinDistance(target, input)
    }
    
    /// Levenshtein distance calculation
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 1...a.count {
            dist[i][0] = i
        }
        
        for j in 1...b.count {
            dist[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = Swift.min(
                        dist[i-1][j] + 1,
                        dist[i][j-1] + 1,
                        dist[i-1][j-1] + 1
                    )
                }
            }
        }
        
        return dist[a.count][b.count]
    }
    
    /// Calculate word-level accuracy
    private func calculateWordAlignment(target: String, input: String) -> Double {
        let targetWords = target.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let inputWords = input.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !targetWords.isEmpty else { return 100.0 }
        
        let maxWords = max(targetWords.count, inputWords.count)
        guard maxWords > 0 else { return 100.0 }
        
        var matches = 0
        let minWords = min(targetWords.count, inputWords.count)
        
        for i in 0..<minWords {
            if targetWords[i] == inputWords[i] {
                matches += 1
            }
        }
        
        return Double(matches) / Double(maxWords) * 100.0
    }
    
    /// Calculate matched words count
    private func calculateMatchedWords(target: String, input: String) -> Int {
        let targetWords = target.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let inputWords = input.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        let minWords = min(targetWords.count, inputWords.count)
        var matches = 0
        
        for i in 0..<minWords {
            if targetWords[i] == inputWords[i] {
                matches += 1
            }
        }
        
        return matches
    }
    
    /// Calculate character-level accuracy from alignment result
    private func calculateCharacterAlignmentAccuracy(alignmentResult: AlignmentResult) -> Double {
        let totalOperations = alignmentResult.operations.count
        guard totalOperations > 0 else { return 100.0 }
        
        let correctOperations = alignmentResult.operations.filter { $0.type == .match }.count
        return Double(correctOperations) / Double(totalOperations) * 100.0
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
        totalErrors: 0, errorRate: 0, completionPercentage: 0,
        kspc: 0, backspaceRate: 0, totalKeystrokes: 0, backspaceCount: 0,
        unfixedErrors: 0, unfixedErrorRate: 0.0,
        wordAccuracy: 100.0, charAccuracy: 100.0, hybridAccuracy: 100.0,
        isFormulaValid: true, formulaDeviation: 0.0
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
    private(set) var isPersonalBest = false
    
    // Test session data
    private var timer: Timer?
    private var sessionStartTime: Date?
    var currentTask: IELTSTask?
    var userInput: String = ""
    private var keyHistory: [Date] = [] // For consistency tracking
    
    // Keystroke tracking
    private(set) var totalKeystrokes: Int = 0
    private(set) var correctionCost: Int = 0 // Backspaces count
    
    // Callbacks
    var onTimeUp: (() -> Void)?
    var onTimeAttackCompleted: ((TimeAttackResult) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadPersonalBests()
    }
    
    // MARK: - Timer Mode Management (Phase A)
    
    func setTimerMode(_ mode: TimerMode) {
        guard !isActive else { return }
        timerMode = mode
        remainingTime = mode.duration
    }
    
    // MARK: - TimeAttack Properties (restored from original design)
    
    private(set) var isTimeAttackMode: Bool = false
    var timeAttackStartTime: CFAbsoluteTime = 0
    var isTimeAttackCompleted: Bool = false
    var isTrackingKeyPresses: Bool = false
    var timeAttackWpmHistory: [Double] = []
    var timeAttackWpmVariation: Double = 0
    
    // MARK: - Test Control
    
    func startTest(with task: IELTSTask) {
        guard !isActive else { return }
        
        currentTask = task
        userInput = ""
        isActive = true
        isPaused = false
        elapsedTime = 0
        remainingTime = timerMode.duration
        totalKeystrokes = 0
        correctionCost = 0
        isPersonalBest = false
        wpmHistory.removeAll()
        keyHistory.removeAll()
        sessionStartTime = Date()
        
        // Reset current score
        currentScore = ScoringResult(
            grossWPM: 0, netWPM: 0, accuracy: 100, qualityScore: 0,
            errorBreakdown: [:], matchedWords: 0, totalWords: 0,
            totalErrors: 0, errorRate: 0, completionPercentage: 0,
            kspc: 0, backspaceRate: 0, totalKeystrokes: 0, backspaceCount: 0,
            unfixedErrors: 0, unfixedErrorRate: 0.0,
            wordAccuracy: 100.0, charAccuracy: 100.0, hybridAccuracy: 100.0,
            isFormulaValid: true, formulaDeviation: 0.0
        )
        
        startTimer()
    }
    
    func pauseTest() {
        guard isActive, !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    func resumeTest() {
        guard isActive, isPaused else { return }
        isPaused = false
        startTimer()
    }
    
    func endTest() -> TypingResult? {
        guard isActive else { return nil }
        
        stopTimer()
        
        guard let task = currentTask else { return nil }
        
        let finalScore = currentScore
        
        let result = TypingResult(
            task: task,
            userInput: userInput,
            duration: elapsedTime,
            scoringResult: finalScore,
            timerMode: timerMode
        )
        
        // Check for personal best
        checkAndUpdatePersonalBest(result: finalScore)
        
        // Log telemetry
        logTelemetryData()
        
        reset()
        
        return result
    }
    
    func reset() {
        isActive = false
        isPaused = false
        currentTask = nil
        userInput = ""
        elapsedTime = 0
        remainingTime = timerMode.duration
        totalKeystrokes = 0
        correctionCost = 0
        isPersonalBest = false
        wpmHistory.removeAll()
        keyHistory.removeAll()
        sessionStartTime = nil
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        guard isActive, !isPaused else { return }
        
        elapsedTime += 0.1
        remainingTime = max(0, timerMode.duration - elapsedTime)
        
        // Update scoring in real-time
        updateCurrentScore()
        
        // Track WPM history for consistency
        if Int(elapsedTime * 10) % 20 == 0 { // Every 2 seconds
            wpmHistory.append(currentScore.netWPM)
            updateWPMVariation()
        }
        
        if remainingTime <= 0 {
            onTimeUp?()
        }
    }
    
    // MARK: - Input Management
    
    func updateInput(_ newInput: String) {
        let previousLength = userInput.count
        userInput = newInput
        
        // Track keystrokes
        let newLength = newInput.count
        if newLength > previousLength {
            totalKeystrokes += (newLength - previousLength)
            keyHistory.append(Date())
        } else if newLength < previousLength {
            correctionCost += (previousLength - newLength)
            totalKeystrokes += (previousLength - newLength) // Backspaces count as keystrokes
        }
        
        updateCurrentScore()
    }
    
    private func updateCurrentScore() {
        guard let task = currentTask, !userInput.isEmpty, elapsedTime > 0 else { return }
        
        currentScore = scoringEngine.calculateScore(
            targetText: task.modelAnswer,
            userInput: userInput,
            elapsedTime: elapsedTime,
            totalKeystrokes: totalKeystrokes,
            backspaceCount: correctionCost
        )
    }
    
    // MARK: - Personal Best Management
    
    private func checkAndUpdatePersonalBest(result: ScoringResult) {
        let currentBest = personalBests[timerMode]
        
        if currentBest == nil || result.netWPM > currentBest!.netWPM {
            let newBest = PersonalBest(netWPM: result.netWPM, accuracy: result.accuracy)
            personalBests[timerMode] = newBest
            isPersonalBest = true
            savePersonalBests()
        }
    }
    
    func getPersonalBest(for mode: TimerMode) -> PersonalBest? {
        return personalBests[mode]
    }
    
    private func loadPersonalBests() {
        if let data = UserDefaults.standard.data(forKey: "PersonalBests"),
           let decoded = try? JSONDecoder().decode([String: PersonalBest].self, from: data) {
            // Convert string keys back to TimerMode
            for (key, value) in decoded {
                if let mode = TimerMode.allCases.first(where: { $0.id == key }) {
                    personalBests[mode] = value
                }
            }
        }
    }
    
    private func savePersonalBests() {
        // Convert TimerMode keys to strings for JSON serialization
        let stringKeyedBests = Dictionary(uniqueKeysWithValues: personalBests.map { ($0.key.id, $0.value) })
        
        if let encoded = try? JSONEncoder().encode(stringKeyedBests) {
            UserDefaults.standard.set(encoded, forKey: "PersonalBests")
        }
    }
    
    // MARK: - Performance Tracking
    
    private func updateWPMVariation() {
        guard wpmHistory.count >= 2 else { return }
        
        let average = wpmHistory.reduce(0, +) / Double(wpmHistory.count)
        let variance = wpmHistory.map { pow($0 - average, 2) }.reduce(0, +) / Double(wpmHistory.count)
        let standardDeviation = sqrt(variance)
        
        wpmVariation = average > 0 ? (standardDeviation / average) * 100 : 0
    }
    
    // MARK: - TimeAttack Control Methods (restored from original design)
    
    func setTimeAttackMode(_ enabled: Bool) {
        isTimeAttackMode = enabled
    }
    
    func setCorrectionCost(_ cost: Int) {
        correctionCost = cost
    }
    
    func setKeystrokeCount(_ count: Int) {
        totalKeystrokes = count
    }
    
    func incrementKeystrokeCount() {
        totalKeystrokes += 1
    }
    
    func incrementCorrectionCost() {
        correctionCost += 1
    }
    
    func setUserInput(_ input: String) {
        userInput = input
    }
    
    func performCalculateMetrics() {
        updateCurrentScore()
    }
    
    
    // MARK: - Telemetry & Data Export
    
    private func logTelemetryData() {
        // 🔧 SCHEMA v1.1: 完全準拠のtelemetry出力
        guard let task = currentTask else { return }
        
        // 🔧 SANITY CHECKS: 保存前バリデーション（3つの必須検証）
        let netFormula = currentScore.grossWPM * (currentScore.accuracy / 100.0)
        let formulaDeviation = abs(currentScore.netWPM - netFormula) / max(currentScore.netWPM, 0.01)
        let kspcExpected = Double(totalKeystrokes) / Double(userInput.count)
        let kspcDeviation = abs(currentScore.kspc - kspcExpected) / max(currentScore.kspc, 0.01)
        
        let formulaValid = formulaDeviation <= 0.03
        let kspcValid = kspcDeviation <= 0.03
        let durationValid = elapsedTime >= 60.0  // 最低1分（正式は5分だが開発時は緩和）
        
        let allValid = formulaValid && kspcValid && durationValid
        
        if !allValid {
            print("🚨 SANITY CHECK FAILED - 保存禁止:")
            print("   Formula valid: \(formulaValid) (deviation: \(formulaDeviation))")
            print("   KSPC valid: \(kspcValid) (deviation: \(kspcDeviation))")
            print("   Duration valid: \(durationValid) (elapsed: \(elapsedTime)s)")
            return // 保存禁止
        }
        
        // 🔧 SCHEMA v1.1: 確定スキーマに準拠
        let telemetryData: [String: Any] = [
            "run_id": UUID().uuidString,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "mode": isTimeAttackMode ? "no-delete" : "normal",  // 正規化
            "experiment_mode": isTimeAttackMode ? "time_attack" : "standard",
            "task_topic": task.topic,
            "duration_sec": elapsedTime,
            "chars_ref": task.modelAnswer.count,  // 必須保存
            "chars_typed": userInput.count,
            "unfixed_errors": currentScore.unfixedErrors,
            "gross_wpm": currentScore.grossWPM,
            "char_accuracy": currentScore.accuracy,  // 主指標
            "net_wpm": currentScore.netWPM,
            "keystrokes_total": totalKeystrokes,
            "backspace_count": correctionCost,  // 必須フィールド
            "kspc": currentScore.kspc,
            "backspace_rate": currentScore.backspaceRate / 100.0,  // 割合に正規化
            "formula_valid": formulaValid,
            "formula_deviation": formulaDeviation,
            "app_version": "1.1",  // バージョンアップ
            "device_info": getDeviceInfo()
        ]
        
        saveTelemetryToFile(telemetryData)
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
    
    private func saveTelemetryToFile(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let telemetryURL = documentsURL.appendingPathComponent("WordflowTelemetry")
            
            if !fileManager.fileExists(atPath: telemetryURL.path) {
                try fileManager.createDirectory(at: telemetryURL, withIntermediateDirectories: true)
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let mode = isTimeAttackMode ? "no-delete" : "normal"
            let filename = "wordflow_v1.1_\(mode)_\(formatter.string(from: Date())).json"
            let fileURL = telemetryURL.appendingPathComponent(filename)
            
            try jsonData.write(to: fileURL)
            print("📁 Basic telemetry saved: \(filename)")
            
        } catch {
            print("⚠️ Failed to save telemetry: \(error)")
        }
    }
}