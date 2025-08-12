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
    let grossWPM: Double        // (総打鍵文字数/5) ÷ 分
    let netWPM: Double          // grossWPM × (accuracy ÷ 100)
    let accuracy: Double        // Smart hybrid accuracy (word + character level)
    let qualityScore: Double    // Net WPM × Accuracy ÷ 100
    let errorBreakdown: [String: Int] // Simplified for now
    let matchedWords: Int
    let totalWords: Int
    let totalErrors: Int
    let errorRate: Double
    let completionPercentage: Double
    
    // Enhanced metrics (Issue #31)
    let kspc: Double           // 総打鍵キー数 ÷ 原文文字数 (Keystrokes Per Character)
    let backspaceRate: Double  // Backspace回数 ÷ 総打鍵キー数
    let totalKeystrokes: Int   // 総打鍵キー数
    let backspaceCount: Int    // Backspace使用回数
    
    // 🔧 FIXED: Unfixed error metrics for proper Net WPM calculation
    let unfixedErrors: Int     // 未修正エラー数
    let unfixedErrorRate: Double // 未修正エラー率 (%)
    
    // 🔧 NEW: Smart accuracy breakdown metrics
    let wordAccuracy: Double   // 単語レベル正確性 (%)
    let charAccuracy: Double   // 文字レベル正確性（編集距離ベース） (%)
    let hybridAccuracy: Double // ハイブリッド正確性（総合） (%)
    
    // 🚨 CRITICAL: Formula validation flag
    let isFormulaValid: Bool   // Net WPM = Gross WPM × Accuracy validation
    let formulaDeviation: Double // Deviation percentage for debugging
    
    // Legacy compatibility
    var characterAccuracy: Double { hybridAccuracy } // Use hybrid accuracy as main accuracy
    var basicErrorCount: Int { totalErrors }
}

// MARK: - Smart Accuracy Metrics
struct SmartAccuracyMetrics {
    let word: Double      // Word-level accuracy
    let character: Double // Character-level accuracy (edit distance)
    let hybrid: Double    // Combined accuracy
}

// MARK: - Global Alignment Support Structures
struct WordAnchor {
    let inputIndex: Int
    let targetIndex: Int
    let word: String
}

struct AlignmentResult {
    let operations: [AlignmentOperation]
    let errorBlocks: [ErrorBlock]
    let unfixedErrors: Int
}

struct AlignmentOperation {
    let type: OperationType
    let inputChar: Character?
    let targetChar: Character?
    let position: Int
    
    enum OperationType {
        case match      // Correct character
        case substitute // Wrong character
        case insert     // Extra character in input
        case delete     // Missing character from target
    }
}

struct ErrorBlock {
    let startPosition: Int
    let length: Int
    let operations: Int
    let type: ErrorBlockType
    
    enum ErrorBlockType {
        case substitution
        case insertion
        case deletion
        case mixed
    }
}

enum NormalizationMode {
    case strict     // IELTS strict mode
    case flexible   // Allow some flexibility
}

// MARK: - Basic Scoring Engine (Phase A)
class BasicScoringEngine {
    // 🔧 CRASH FIX: Safe default result for error cases
    private func createDefaultScoringResult() -> ScoringResult {
        return ScoringResult(
            grossWPM: 0.0, netWPM: 0.0, accuracy: 0.0, qualityScore: 0.0,
            errorBreakdown: [:], matchedWords: 0, totalWords: 0,
            totalErrors: 0, errorRate: 0.0, completionPercentage: 0.0,
            kspc: 1.0, backspaceRate: 0.0, totalKeystrokes: 0, backspaceCount: 0,
            unfixedErrors: 0, unfixedErrorRate: 0.0,
            wordAccuracy: 0.0, charAccuracy: 0.0, hybridAccuracy: 0.0,
            isFormulaValid: false, formulaDeviation: 0.0
        )
    }
    
    func calculateScore(userInput: String, targetText: String, elapsedTime: TimeInterval, keystrokes: Int = 0, backspaceCount: Int = 0) -> ScoringResult {
        // 🔧 CRASH FIX: Safe parameter validation
        guard elapsedTime > 0, !targetText.isEmpty else {
            print("⚠️ Warning: Invalid parameters for scoring calculation")
            return createDefaultScoringResult()
        }
        
        let elapsedMinutes = max(0.001, elapsedTime / 60.0)
        
        // 🎯 OFFICIAL SPECIFICATION: Fixed formula implementation
        let typedText = userInput
        let referenceText = targetText
        let outputChars = Double(typedText.count)
        
        // 🔧 CRASH FIX: Calculate Levenshtein distance safely with bounds checking
        let unfixedErrors: Double
        if typedText.count > 10000 || referenceText.count > 10000 {
            print("⚠️ Warning: Text too long for precise calculation, using approximation")
            unfixedErrors = max(0.0, abs(Double(typedText.count) - Double(referenceText.count)))
        } else {
            unfixedErrors = Double(levenshteinDistance(typedText, referenceText))
        }
        
        // Gross WPM = (output_chars / 5) / minutes
        let grossWPM = (outputChars / 5.0) / elapsedMinutes
        
        // Accuracy = max(0, 100 * (output_chars - unfixed_errors) / output_chars)
        let accuracy = outputChars > 0 ? max(0.0, 100.0 * (outputChars - unfixedErrors) / outputChars) : 0.0
        
        // Net WPM = gross_wpm * (accuracy_pct / 100)
        let netWPM = grossWPM * (accuracy / 100.0)
        
        // 🎯 OFFICIAL SPECIFICATION: Additional calculations
        
        // KSPC = keystrokes_total / output_chars (must be ≥ 1.0)
        let kspc = outputChars > 0 ? max(1.0, Double(keystrokes) / outputChars) : 1.0
        
        // Backspace rate = backspace_count / keystrokes_total (must be ≤ 0.25)
        let backspaceRate = keystrokes > 0 ? min(25.0, Double(backspaceCount) / Double(keystrokes) * 100.0) : 0.0
        
        // Quality Score = Net WPM × Accuracy ÷ 100
        let qualityScore = netWPM * accuracy / 100.0
        
        // Completion percentage (separate from accuracy)
        let userWords = tokenizeWords(userInput)
        let targetWords = tokenizeWords(targetText)
        let completionPercentage = targetWords.count > 0 ? 
            min(100.0, Double(userWords.count) / Double(targetWords.count) * 100.0) : 0.0
        
        // 🚨 SANITY CHECK: Critical formula validation
        let expectedNetWPM = grossWPM * (accuracy / 100.0)
        let netWPMDeviation = expectedNetWPM > 0 ? abs(netWPM - expectedNetWPM) / expectedNetWPM : 0.0
        let netWPMValid = netWPMDeviation <= 0.03
        
        // 🔧 SANITY CHECK: KSPC formula validation
        let expectedKSPC = outputChars > 0 ? Double(keystrokes) / outputChars : 1.0
        let kspcDeviation = expectedKSPC > 0 ? abs(kspc - expectedKSPC) / expectedKSPC : 0.0
        let kspcValid = kspcDeviation <= 0.03
        
        let isFormulaValid = netWPMValid && kspcValid
        
        // Ensure accuracy bounds: 0 ≤ accuracy ≤ 100
        let clampedAccuracy = max(0.0, min(100.0, accuracy))
        
        // 🚨 OFFICIAL SPECIFICATION: Debug validation output
        #if DEBUG
        print("🎯 OFFICIAL FORMULA VALIDATION:")
        print("   Duration: \(String(format: "%.2f", elapsedTime))s = \(String(format: "%.4f", elapsedMinutes))min")
        print("   Output chars: \(Int(outputChars)), Reference chars: \(referenceText.count)")
        print("   Unfixed errors (Levenshtein): \(Int(unfixedErrors))")
        print("   Gross WPM: \(String(format: "%.1f", grossWPM)) = (\(Int(outputChars))/5)/\(String(format: "%.4f", elapsedMinutes))")
        print("   Accuracy: \(String(format: "%.1f", clampedAccuracy))% = max(0, 100*(\(Int(outputChars))-\(Int(unfixedErrors)))/\(Int(outputChars)))")
        print("   Net WPM: \(String(format: "%.1f", netWPM)) = \(String(format: "%.1f", grossWPM)) × \(String(format: "%.3f", clampedAccuracy/100.0))")
        print("   🔧 KSPC DEBUG: \(String(format: "%.2f", kspc)) = \(keystrokes)/\(Int(outputChars)) (keystrokes/OUTPUT_CHARS)")
        print("   🔧 KSPC SHOULD BE: \(keystrokes > 0 && outputChars > 0 ? String(format: "%.2f", Double(keystrokes)/outputChars) : "N/A")")
        print("   Backspace rate: \(String(format: "%.1f", backspaceRate))% = \(backspaceCount)/\(keystrokes)")
        
        // 🚨 SANITY CHECK RESULTS
        print("   🔍 SANITY CHECKS:")
        print("     Net WPM: \(netWPMValid ? "✅" : "🚨") deviation \(String(format: "%.1f%%", netWPMDeviation * 100)) \(netWPMValid ? "≤" : ">") 3%")
        print("     KSPC: \(kspcValid ? "✅" : "🚨") deviation \(String(format: "%.1f%%", kspcDeviation * 100)) \(kspcValid ? "≤" : ">") 3%")
        print("     Overall: \(isFormulaValid ? "✅ PASSED" : "🚨 FAILED")")
        
        if !isFormulaValid {
            print("   ⚠️ CRITICAL: Sanity check failed - calculations may be incorrect!")
        }
        
        // 🔧 JSON TELEMETRY LOGGING
        logTelemetryData(
            mode: "time_attack",
            sourceId: "unknown",
            charsRef: referenceText.count,
            charsTyped: Int(outputChars),
            keystrokesTotal: keystrokes,
            backspaceCount: backspaceCount,
            unfixedErrors: Int(unfixedErrors),
            durationSec: elapsedTime,
            grossWPM: grossWPM,
            netWPM: netWPM,
            accuracy: clampedAccuracy,
            kspc: kspc,
            isFormulaValid: isFormulaValid,
            netWPMDeviation: netWPMDeviation,
            kspcDeviation: kspcDeviation
        )
        #endif
        
        return ScoringResult(
            grossWPM: grossWPM,
            netWPM: netWPM,
            accuracy: clampedAccuracy,  // Use clamped accuracy
            qualityScore: qualityScore,
            errorBreakdown: [:],
            matchedWords: Int((outputChars - unfixedErrors) / 5.0), // Correct characters as words
            totalWords: targetWords.count,
            totalErrors: Int(unfixedErrors), // Unfixed errors count
            errorRate: unfixedErrors > 0 ? (unfixedErrors / outputChars * 100.0) : 0.0,
            completionPercentage: completionPercentage,
            kspc: kspc,
            backspaceRate: backspaceRate,
            totalKeystrokes: keystrokes,
            backspaceCount: backspaceCount,
            unfixedErrors: Int(unfixedErrors),
            unfixedErrorRate: unfixedErrors > 0 ? (unfixedErrors / outputChars * 100.0) : 0.0,
            wordAccuracy: clampedAccuracy,     // Simplified - use same accuracy
            charAccuracy: clampedAccuracy,     // Simplified - use same accuracy
            hybridAccuracy: clampedAccuracy,   // Simplified - use same accuracy
            isFormulaValid: isFormulaValid,
            formulaDeviation: netWPMDeviation * 100.0
        )
    }
    
    // 🔧 NEW: Global alignment-based accuracy calculation (fixes cascading error issue)
    private func calculateSmartAccuracyDetailed(userInput: String, targetText: String) -> SmartAccuracyMetrics {
        // Handle empty input
        guard !userInput.isEmpty else { 
            return SmartAccuracyMetrics(word: 100.0, character: 100.0, hybrid: 100.0)
        }
        
        // 🎯 ROBUST IMPLEMENTATION: Global alignment approach
        let normalizedInput = normalizeText(userInput, mode: .flexible)
        let normalizedTarget = normalizeText(targetText, mode: .flexible)
        
        // Phase 1: Word-level LCS anchoring to prevent cascading errors
        let inputWords = tokenizeWords(normalizedInput)
        let targetWords = tokenizeWords(normalizedTarget)
        let wordAnchors = findWordAnchors(inputWords: inputWords, targetWords: targetWords)
        
        // Phase 2: Character-level alignment within anchor segments
        let alignmentResult = performGlobalAlignment(
            userInput: normalizedInput, 
            targetText: normalizedTarget,
            wordAnchors: wordAnchors
        )
        
        // Calculate accuracies based on global alignment
        let wordAccuracy = calculateWordAlignmentAccuracy(alignmentResult: alignmentResult, inputWords: inputWords, targetWords: targetWords)
        let charAccuracy = calculateCharacterAlignmentAccuracy(alignmentResult: alignmentResult)
        
        // Hybrid approach: combine word and character accuracy with global alignment weights
        let hybridAccuracy = (wordAccuracy * 0.65) + (charAccuracy * 0.35)
        
        #if DEBUG
        print("🎯 Global Alignment Debug:")
        print("   Word anchors: \(wordAnchors.count), Input words: \(inputWords.count), Target words: \(targetWords.count)")
        print("   Alignment ops: \(alignmentResult.operations.count), Error blocks: \(alignmentResult.errorBlocks.count)")
        print("   Word accuracy: \(String(format: "%.1f", wordAccuracy))% (weight: 65%)")
        print("   Character accuracy: \(String(format: "%.1f", charAccuracy))% (weight: 35%)")
        print("   Hybrid accuracy: \(String(format: "%.1f", hybridAccuracy))%")
        #endif
        
        return SmartAccuracyMetrics(word: wordAccuracy, character: charAccuracy, hybrid: hybridAccuracy)
    }
    
    // Legacy wrapper for compatibility
    private func calculateSmartAccuracy(userInput: String, targetText: String) -> Double {
        return calculateSmartAccuracyDetailed(userInput: userInput, targetText: targetText).hybrid
    }
    
    // Calculate word-level accuracy (exact word matches)
    private func calculateWordAccuracy(inputWords: [String], targetWords: [String]) -> Double {
        guard !targetWords.isEmpty else { return 100.0 }
        
        let comparisonCount = min(inputWords.count, targetWords.count)
        guard comparisonCount > 0 else { return 0.0 }
        
        var correctWords = 0
        for i in 0..<comparisonCount {
            if inputWords[i] == targetWords[i] {
                correctWords += 1
            }
        }
        
        // Consider length mismatch as penalty
        let lengthPenalty = abs(inputWords.count - targetWords.count)
        let totalWords = max(inputWords.count, targetWords.count)
        
        let accuracy = Double(correctWords) / Double(totalWords) * 100.0
        
        #if DEBUG
        print("   Word comparison: \(correctWords)/\(comparisonCount) matches, penalty: \(lengthPenalty)")
        #endif
        
        return max(0.0, accuracy)
    }
    
    // Calculate accuracy using Levenshtein distance (edit distance)
    private func calculateEditDistanceAccuracy(userInput: String, targetText: String) -> Double {
        let distance = levenshteinDistance(userInput, targetText)
        let maxLength = max(userInput.count, targetText.count)
        
        guard maxLength > 0 else { return 100.0 }
        
        // Convert edit distance to accuracy percentage
        let accuracy = (1.0 - Double(distance) / Double(maxLength)) * 100.0
        return max(0.0, accuracy)
    }
    
    // 🔧 CRASH FIX: Safe Levenshtein distance algorithm with bounds checking
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        // Handle empty strings early to prevent crashes
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        // Safety check for very large strings to prevent memory issues
        guard s1Count <= 10000 && s2Count <= 10000 else {
            print("⚠️ Warning: String too long for Levenshtein calculation, using approximation")
            return max(s1Count, s2Count) // Worst-case approximation
        }
        
        // 🔧 CRASH FIX: Create matrix with extra safety checks
        guard s1Count >= 0 && s2Count >= 0 else {
            print("⚠️ Negative string counts: s1Count=\(s1Count), s2Count=\(s2Count)")
            return max(s1.count, s2.count)
        }
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        // Initialize first row and column with bounds checking
        for i in 0...s1Count {
            if i < matrix.count {
                matrix[i][0] = i
            }
        }
        for j in 0...s2Count {
            if matrix.count > 0 && j < matrix[0].count {
                matrix[0][j] = j
            }
        }
        
        // Fill the matrix with bounds checking
        for i in 1...s1Count {
            for j in 1...s2Count {
                // Bounds checking for array access
                guard i < matrix.count && j < matrix[i].count && 
                      i-1 < s1Array.count && j-1 < s2Array.count else {
                    continue
                }
                
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,    // deletion
                    matrix[i][j-1] + 1,    // insertion
                    matrix[i-1][j-1] + cost // substitution
                )
            }
        }
        
        // 🔧 CRASH FIX: Ultra-safe matrix access with comprehensive bounds checking
        guard matrix.count > 0 && !matrix.isEmpty else {
            print("⚠️ Empty matrix error")
            return max(s1Count, s2Count)
        }
        
        guard matrix[0].count > 0 else {
            print("⚠️ Empty matrix row error")
            return max(s1Count, s2Count)
        }
        
        // 🔧 Additional validation: ensure counts match array lengths
        guard s1Count == s1Array.count && s2Count == s2Array.count else {
            print("⚠️ Count mismatch: s1Count=\(s1Count) vs s1Array.count=\(s1Array.count), s2Count=\(s2Count) vs s2Array.count=\(s2Array.count)")
            return abs(s1Array.count - s2Array.count) // Return difference as approximation
        }
        
        guard s1Count >= 0 && s2Count >= 0 && 
              s1Count < matrix.count && s2Count < matrix[0].count else {
            print("⚠️ Matrix bounds error: s1Count=\(s1Count), s2Count=\(s2Count), matrix=\(matrix.count)x\(matrix[0].count)")
            print("   s1='\(s1.prefix(20))' s2='\(s2.prefix(20))'")
            return max(s1Count, s2Count) // Fallback to maximum possible distance
        }
        
        return matrix[s1Count][s2Count]
    }
    
    // Legacy function for compatibility (now calls smart accuracy)
    private func calculateCharacterAccuracy(userInput: String, targetText: String) -> Double {
        #if DEBUG
        print("⚠️ Using legacy calculateCharacterAccuracy - consider updating to calculateSmartAccuracy")
        #endif
        return calculateSmartAccuracy(userInput: userInput, targetText: targetText)
    }
    
    // 🔧 ENHANCED: Configurable text normalization for comparison
    private func normalizeText(_ text: String, mode: NormalizationMode = .strict) -> String {
        var normalized = text
            // Line ending normalization
            .replacingOccurrences(of: "\r\n", with: "\n")  // Windows line endings
            .replacingOccurrences(of: "\r", with: "\n")    // Mac classic line endings
            // Space normalization
            .replacingOccurrences(of: "\t", with: " ")     // Tab to space
            .replacingOccurrences(of: "\u{00A0}", with: " ") // Non-breaking space to space
            .replacingOccurrences(of: "\u{3000}", with: " ") // Ideographic space to space
            // Unicode normalization (decomposed → composed form)
            .precomposedStringWithCanonicalMapping
        
        switch mode {
        case .strict:
            // IELTS strict mode - preserve exact spacing and punctuation
            normalized = normalized
                // Remove only control characters except newlines and spaces
                .filter { char in
                    let unicodeScalar = char.unicodeScalars.first
                    let isControlChar = unicodeScalar?.properties.generalCategory == .control
                    return !isControlChar || char.isNewline || char.isWhitespace
                }
        case .flexible:
            // Flexible mode - normalize multiple spaces and convert newlines
            normalized = normalized
                // Collapse multiple spaces
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                // Convert newlines to spaces for more flexible comparison
                .replacingOccurrences(of: "\n", with: " ")
                // Remove control characters
                .filter { char in
                    let unicodeScalar = char.unicodeScalars.first
                    let isControlChar = unicodeScalar?.properties.generalCategory == .control
                    return !isControlChar
                }
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    // MARK: - Global Alignment Implementation
    
    /// 🔧 Phase 1: Find word-level anchors using LCS to prevent cascading errors
    private func findWordAnchors(inputWords: [String], targetWords: [String]) -> [WordAnchor] {
        var anchors: [WordAnchor] = []
        
        // Simple LCS-based word matching to establish anchor points
        let lcs = longestCommonSubsequence(inputWords, targetWords)
        
        var inputIndex = 0
        var targetIndex = 0
        
        for commonWord in lcs {
            // Find next occurrence of common word in both sequences
            while inputIndex < inputWords.count && inputWords[inputIndex] != commonWord {
                inputIndex += 1
            }
            while targetIndex < targetWords.count && targetWords[targetIndex] != commonWord {
                targetIndex += 1
            }
            
            if inputIndex < inputWords.count && targetIndex < targetWords.count {
                anchors.append(WordAnchor(inputIndex: inputIndex, targetIndex: targetIndex, word: commonWord))
                inputIndex += 1
                targetIndex += 1
            }
        }
        
        return anchors
    }
    
    /// Longest Common Subsequence for word-level matching
    private func longestCommonSubsequence(_ seq1: [String], _ seq2: [String]) -> [String] {
        let m = seq1.count
        let n = seq2.count
        
        // DP table for LCS length
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Fill DP table
        for i in 1...m {
            for j in 1...n {
                if seq1[i-1] == seq2[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        
        // Backtrack to get actual LCS
        var lcs: [String] = []
        var i = m, j = n
        
        while i > 0 && j > 0 {
            if seq1[i-1] == seq2[j-1] {
                lcs.insert(seq1[i-1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs
    }
    
    /// 🔧 Phase 2: Perform global alignment with Needleman-Wunsch on character segments
    private func performGlobalAlignment(userInput: String, targetText: String, wordAnchors: [WordAnchor]) -> AlignmentResult {
        let inputChars = Array(userInput)
        let targetChars = Array(targetText)
        
        // Perform Needleman-Wunsch alignment between anchor points
        let operations = needlemanWunschAlignment(inputChars, targetChars)
        
        // Group operations into error blocks
        let errorBlocks = groupIntoErrorBlocks(operations)
        
        // Count unfixed errors (substitutions + insertions + deletions)
        let unfixedErrors = operations.filter { $0.type != .match }.count
        
        return AlignmentResult(operations: operations, errorBlocks: errorBlocks, unfixedErrors: unfixedErrors)
    }
    
    /// Needleman-Wunsch global alignment algorithm (simplified with cost=1 for all operations)
    private func needlemanWunschAlignment(_ seq1: [Character], _ seq2: [Character]) -> [AlignmentOperation] {
        let m = seq1.count
        let n = seq2.count
        
        // Initialize scoring matrix
        var score = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize first row and column (gap penalties)
        for i in 0...m {
            score[i][0] = -i  // Gap penalty = 1
        }
        for j in 0...n {
            score[0][j] = -j  // Gap penalty = 1
        }
        
        // Fill scoring matrix
        for i in 1...m {
            for j in 1...n {
                let matchScore = score[i-1][j-1] + (seq1[i-1] == seq2[j-1] ? 2 : -1) // Match = +2, Mismatch = -1
                let deleteScore = score[i-1][j] - 1  // Deletion penalty = 1
                let insertScore = score[i][j-1] - 1  // Insertion penalty = 1
                
                score[i][j] = max(matchScore, max(deleteScore, insertScore))
            }
        }
        
        // Backtrack to get alignment
        var operations: [AlignmentOperation] = []
        var i = m, j = n
        var position = 0
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && score[i][j] == score[i-1][j-1] + (seq1[i-1] == seq2[j-1] ? 2 : -1) {
                // Match or substitution
                let opType: AlignmentOperation.OperationType = seq1[i-1] == seq2[j-1] ? .match : .substitute
                operations.insert(AlignmentOperation(type: opType, inputChar: seq1[i-1], targetChar: seq2[j-1], position: position), at: 0)
                i -= 1
                j -= 1
            } else if i > 0 && score[i][j] == score[i-1][j] - 1 {
                // Deletion (missing in input)
                operations.insert(AlignmentOperation(type: .delete, inputChar: nil, targetChar: seq2[j-1], position: position), at: 0)
                i -= 1
            } else {
                // Insertion (extra in input)
                operations.insert(AlignmentOperation(type: .insert, inputChar: seq1[i-1], targetChar: nil, position: position), at: 0)
                j -= 1
            }
            position += 1
        }
        
        return operations
    }
    
    /// Group consecutive error operations into error blocks for UI display
    private func groupIntoErrorBlocks(_ operations: [AlignmentOperation]) -> [ErrorBlock] {
        var blocks: [ErrorBlock] = []
        var currentBlock: [AlignmentOperation] = []
        
        for operation in operations {
            if operation.type == .match {
                // End current error block if it exists
                if !currentBlock.isEmpty {
                    blocks.append(createErrorBlock(from: currentBlock))
                    currentBlock.removeAll()
                }
            } else {
                // Add to current error block
                currentBlock.append(operation)
            }
        }
        
        // Handle final block
        if !currentBlock.isEmpty {
            blocks.append(createErrorBlock(from: currentBlock))
        }
        
        return blocks
    }
    
    private func createErrorBlock(from operations: [AlignmentOperation]) -> ErrorBlock {
        guard let firstOp = operations.first else {
            return ErrorBlock(startPosition: 0, length: 0, operations: 0, type: .mixed)
        }
        
        let types = Set(operations.map { $0.type })
        let blockType: ErrorBlock.ErrorBlockType
        
        if types.count == 1 {
            switch types.first! {
            case .substitute: blockType = .substitution
            case .insert: blockType = .insertion
            case .delete: blockType = .deletion
            case .match: blockType = .mixed // Shouldn't happen
            }
        } else {
            blockType = .mixed
        }
        
        return ErrorBlock(
            startPosition: firstOp.position,
            length: operations.count,
            operations: operations.count,
            type: blockType
        )
    }
    
    /// Calculate word-level accuracy from alignment result
    private func calculateWordAlignmentAccuracy(alignmentResult: AlignmentResult, inputWords: [String], targetWords: [String]) -> Double {
        // Simple word-level accuracy: correctly typed words / total target words
        let totalTargetWords = targetWords.count
        guard totalTargetWords > 0 else { return 100.0 }
        
        // Count error blocks that affect whole words (rough approximation)
        let majorErrorBlocks = alignmentResult.errorBlocks.filter { $0.length > 3 }
        let minorErrorBlocks = alignmentResult.errorBlocks.filter { $0.length <= 3 }
        
        let estimatedAffectedWords = majorErrorBlocks.count + (minorErrorBlocks.count / 2)
        let correctWords = max(0, totalTargetWords - estimatedAffectedWords)
        
        return Double(correctWords) / Double(totalTargetWords) * 100.0
    }
    
    /// Calculate character-level accuracy from alignment result
    private func calculateCharacterAlignmentAccuracy(alignmentResult: AlignmentResult) -> Double {
        let totalOperations = alignmentResult.operations.count
        guard totalOperations > 0 else { return 100.0 }
        
        let correctOperations = alignmentResult.operations.filter { $0.type == .match }.count
        return Double(correctOperations) / Double(totalOperations) * 100.0
    }
    
    // MARK: - Telemetry & Validation
    
    /// 🚨 JSON TELEMETRY: Log detailed typing metrics for validation and debugging
    private func logTelemetryData(
        mode: String,
        sourceId: String,
        charsRef: Int,
        charsTyped: Int,
        keystrokesTotal: Int,
        backspaceCount: Int,
        unfixedErrors: Int,
        durationSec: Double,
        grossWPM: Double,
        netWPM: Double,
        accuracy: Double,
        kspc: Double,
        isFormulaValid: Bool,
        netWPMDeviation: Double,
        kspcDeviation: Double
    ) {
        let telemetryData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "mode": mode,
            "source_id": sourceId,
            "chars_ref": charsRef,
            "chars_typed": charsTyped,
            "keystrokes_total": keystrokesTotal,
            "backspace_count": backspaceCount,
            "unfixed_errors": unfixedErrors,
            "duration_sec": String(format: "%.3f", durationSec),
            "gross_wpm": String(format: "%.2f", grossWPM),
            "net_wpm": String(format: "%.2f", netWPM),
            "accuracy_pct": String(format: "%.2f", accuracy),
            "kspc": String(format: "%.3f", kspc),
            "app_version": "1.0",
            "formula_valid": isFormulaValid,
            "net_wpm_deviation": String(format: "%.4f", netWPMDeviation),
            "kspc_deviation": String(format: "%.4f", kspcDeviation),
            "sanity_check": [
                "net_wpm_formula": isFormulaValid ? "PASS" : "FAIL",
                "kspc_formula": kspcDeviation <= 0.03 ? "PASS" : "FAIL"
            ]
        ]
        
        // Convert to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: telemetryData, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔧 TELEMETRY JSON:")
                print(jsonString)
                
                // TODO: Optional file logging to ~/Documents/WordflowTelemetry/
                #if DEBUG
                writeToTelemetryFile(jsonString)
                #endif
            }
        } catch {
            print("⚠️ Failed to serialize telemetry data: \(error)")
        }
    }
    
    /// Write telemetry data to file for debugging
    private func writeToTelemetryFile(_ jsonString: String) {
        let fileManager = FileManager.default
        
        // Get Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access Documents directory")
            return
        }
        
        // Create WordflowTelemetry directory
        let telemetryURL = documentsURL.appendingPathComponent("WordflowTelemetry")
        
        do {
            if !fileManager.fileExists(atPath: telemetryURL.path) {
                try fileManager.createDirectory(at: telemetryURL, withIntermediateDirectories: true)
            }
            
            // Create filename with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let filename = "typing_metrics_\(formatter.string(from: Date())).json"
            let fileURL = telemetryURL.appendingPathComponent(filename)
            
            // Write JSON to file
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📁 Telemetry logged to: \(fileURL.path)")
            
        } catch {
            print("⚠️ Failed to write telemetry file: \(error)")
        }
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
    private(set) var isPersonalBest: Bool = false
    
    // Time Attack Mode Properties
    private(set) var isTimeAttackMode: Bool = false
    private(set) var correctionCost: Int = 0
    private(set) var totalKeystrokes: Int = 0  // Total keystroke count
    var isTrackingKeyPresses: Bool = false
    var timeAttackStartTime: CFAbsoluteTime = 0.0
    var isTimeAttackCompleted: Bool = false
    var onTimeAttackCompleted: ((TimeAttackResult) -> Void)?
    
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
            elapsedTime: elapsedTime,
            keystrokes: totalKeystrokes,
            backspaceCount: correctionCost
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
            totalErrors: 0, errorRate: 0, completionPercentage: 0,
            kspc: 0, backspaceRate: 0, totalKeystrokes: 0, backspaceCount: 0,
            unfixedErrors: 0, unfixedErrorRate: 0.0,
            wordAccuracy: 100.0, charAccuracy: 100.0, hybridAccuracy: 100.0,
            isFormulaValid: true, formulaDeviation: 0.0
        )
        wpmHistory.removeAll()
        wpmVariation = 0
    }
    
    private func reset() {
        currentTask = nil
        userInput = ""
        resetMetrics()
    }
    
    // MARK: - Time Attack Internal Methods
    
    internal func setTimeAttackMode(_ value: Bool) {
        isTimeAttackMode = value
    }
    
    internal func setCorrectionCost(_ value: Int) {
        correctionCost = value
    }
    
    internal func incrementCorrectionCost() {
        correctionCost += 1
        // Also count as keystroke
        totalKeystrokes += 1
    }
    
    internal func incrementKeystrokeCount() {
        totalKeystrokes += 1
    }
    
    internal func setKeystrokeCount(_ value: Int) {
        totalKeystrokes = value
    }
    
    internal func setUserInput(_ input: String) {
        userInput = input
    }
    
    internal func performCalculateMetrics() {
        calculateMetrics()
    }
    
    internal var timeAttackWpmHistory: [Double] {
        return wpmHistory
    }
    
    internal var timeAttackWpmVariation: Double {
        return wpmVariation
    }
}