//
//  BasicErrorCounter.swift
//  Wordflow - Typing Practice App
//

import Foundation

// Enhanced error detection system with detailed analysis
struct BasicErrorCounter {
    func countBasicErrors(input: String, target: String) -> BasicErrorInfo {
        let minLength = min(input.count, target.count)
        var errorPositions: [Int] = []
        var correctCount = 0
        
        // Simple character comparison
        for i in 0..<minLength {
            let inputChar = input[input.index(input.startIndex, offsetBy: i)]
            let targetChar = target[target.index(target.startIndex, offsetBy: i)]
            
            if inputChar == targetChar {
                correctCount += 1
            } else {
                errorPositions.append(i)
            }
        }
        
        // Add errors for extra characters in input
        if input.count > target.count {
            for i in target.count..<input.count {
                errorPositions.append(i)
            }
        }
        
        let totalErrors = input.count - correctCount
        let errorRate = input.count > 0 ? Double(totalErrors) / Double(input.count) * 100 : 0
        
        return BasicErrorInfo(
            totalErrors: max(0, totalErrors),
            errorRate: errorRate,
            errorPositions: errorPositions
        )
    }
    
    // Enhanced error analysis with detailed categorization
    func analyzeErrors(input: String, target: String) -> DetailedErrorAnalysis {
        let analysis = performDetailedAnalysis(input: input, target: target)
        return analysis
    }
    
    private func performDetailedAnalysis(input: String, target: String) -> DetailedErrorAnalysis {
        let inputChars = Array(input)
        let targetChars = Array(target)
        let minLength = min(inputChars.count, targetChars.count)
        
        var errorBreakdown: [ErrorType: Int] = [:]
        var characterErrors: [CharacterError] = []
        var correctCount = 0
        
        // Analyze character-by-character
        for i in 0..<minLength {
            let inputChar = inputChars[i]
            let targetChar = targetChars[i]
            
            if inputChar == targetChar {
                correctCount += 1
            } else {
                let errorType = categorizeError(input: inputChar, target: targetChar)
                errorBreakdown[errorType, default: 0] += 1
                
                characterErrors.append(CharacterError(
                    position: i,
                    inputChar: inputChar,
                    targetChar: targetChar,
                    errorType: errorType
                ))
            }
        }
        
        // Handle extra characters in input (insertions)
        if inputChars.count > targetChars.count {
            let insertionCount = inputChars.count - targetChars.count
            errorBreakdown[.insertion, default: 0] += insertionCount
            
            for i in targetChars.count..<inputChars.count {
                characterErrors.append(CharacterError(
                    position: i,
                    inputChar: inputChars[i],
                    targetChar: nil,
                    errorType: .insertion
                ))
            }
        }
        
        // Handle missing characters (omissions)
        if targetChars.count > inputChars.count {
            let omissionCount = targetChars.count - inputChars.count
            errorBreakdown[.omission, default: 0] += omissionCount
        }
        
        let totalErrors = characterErrors.count
        let accuracy = inputChars.count > 0 ? Double(correctCount) / Double(inputChars.count) * 100.0 : 100.0
        let completionRate = targetChars.count > 0 ? Double(inputChars.count) / Double(targetChars.count) * 100.0 : 0.0
        
        return DetailedErrorAnalysis(
            totalErrors: totalErrors,
            accuracy: accuracy,
            completionRate: completionRate,
            errorBreakdown: errorBreakdown,
            characterErrors: characterErrors,
            mostCommonErrors: findMostCommonErrors(errorBreakdown),
            suggestions: generateSuggestions(errorBreakdown, characterErrors)
        )
    }
    
    private func categorizeError(input: Character, target: Character) -> ErrorType {
        // Case sensitivity errors
        if input.lowercased() == target.lowercased() {
            return .caseError
        }
        
        // Whitespace/punctuation errors
        if input.isWhitespace || target.isWhitespace {
            return .whitespaceError
        }
        if input.isPunctuation || target.isPunctuation {
            return .punctuationError
        }
        
        // Similar characters (common typos)
        let inputStr = String(input)
        let targetStr = String(target)
        
        // Common adjacent key errors (QWERTY layout)
        let adjacentKeys: [String: [String]] = [
            "q": ["w", "a"], "w": ["q", "e", "a", "s"], "e": ["w", "r", "s", "d"],
            "r": ["e", "t", "d", "f"], "t": ["r", "y", "f", "g"], "y": ["t", "u", "g", "h"],
            "u": ["y", "i", "h", "j"], "i": ["u", "o", "j", "k"], "o": ["i", "p", "k", "l"],
            "p": ["o", "l"], "a": ["q", "w", "s", "z"], "s": ["a", "w", "e", "d", "z", "x"],
            "d": ["s", "e", "r", "f", "x", "c"], "f": ["d", "r", "t", "g", "c", "v"],
            "g": ["f", "t", "y", "h", "v", "b"], "h": ["g", "y", "u", "j", "b", "n"],
            "j": ["h", "u", "i", "k", "n", "m"], "k": ["j", "i", "o", "l", "m"],
            "l": ["k", "o", "p", "m"], "z": ["a", "s", "x"], "x": ["z", "s", "d", "c"],
            "c": ["x", "d", "f", "v"], "v": ["c", "f", "g", "b"], "b": ["v", "g", "h", "n"],
            "n": ["b", "h", "j", "m"], "m": ["n", "j", "k", "l"]
        ]
        
        if let adjacents = adjacentKeys[inputStr.lowercased()],
           adjacents.contains(targetStr.lowercased()) {
            return .adjacentKeyError
        }
        
        // Number errors
        if input.isNumber || target.isNumber {
            return .numberError
        }
        
        // Default substitution error
        return .substitutionError
    }
    
    private func findMostCommonErrors(_ breakdown: [ErrorType: Int]) -> [ErrorType] {
        return breakdown.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }
    
    private func generateSuggestions(_ breakdown: [ErrorType: Int], _ errors: [CharacterError]) -> [String] {
        var suggestions: [String] = []
        
        if breakdown[.caseError, default: 0] > 0 {
            suggestions.append("Practice maintaining proper capitalization")
        }
        
        if breakdown[.adjacentKeyError, default: 0] > 2 {
            suggestions.append("Focus on finger placement to avoid adjacent key mistakes")
        }
        
        if breakdown[.whitespaceError, default: 0] > 0 {
            suggestions.append("Pay attention to spacing between words")
        }
        
        if breakdown[.punctuationError, default: 0] > 0 {
            suggestions.append("Take care with punctuation marks")
        }
        
        if breakdown[.insertion, default: 0] > 3 {
            suggestions.append("Slow down to avoid extra keystrokes")
        }
        
        if breakdown[.omission, default: 0] > 2 {
            suggestions.append("Read more carefully to avoid missing characters")
        }
        
        return suggestions
    }
}

struct BasicErrorInfo {
    let totalErrors: Int
    let errorRate: Double
    let errorPositions: [Int]
}

// MARK: - Enhanced Error Analysis Types

enum ErrorType: String, CaseIterable, Hashable {
    case substitutionError = "substitution"
    case caseError = "case"
    case whitespaceError = "whitespace" 
    case punctuationError = "punctuation"
    case adjacentKeyError = "adjacent_key"
    case numberError = "number"
    case insertion = "insertion"
    case omission = "omission"
    
    var displayName: String {
        switch self {
        case .substitutionError: return "Wrong Character"
        case .caseError: return "Case Error"
        case .whitespaceError: return "Spacing Error"
        case .punctuationError: return "Punctuation Error"
        case .adjacentKeyError: return "Adjacent Key Error"
        case .numberError: return "Number Error"
        case .insertion: return "Extra Character"
        case .omission: return "Missing Character"
        }
    }
    
    var description: String {
        switch self {
        case .substitutionError: return "Typed a different character"
        case .caseError: return "Wrong capitalization"
        case .whitespaceError: return "Incorrect spacing"
        case .punctuationError: return "Wrong punctuation mark"
        case .adjacentKeyError: return "Pressed adjacent key by mistake"
        case .numberError: return "Number typing error"
        case .insertion: return "Added extra character"
        case .omission: return "Skipped required character"
        }
    }
    
    var iconName: String {
        switch self {
        case .substitutionError: return "character.cursor.ibeam"
        case .caseError: return "textformat.size"
        case .whitespaceError: return "space"
        case .punctuationError: return "dot.radiowaves.left.and.right"
        case .adjacentKeyError: return "keyboard"
        case .numberError: return "number"
        case .insertion: return "plus.circle"
        case .omission: return "minus.circle"
        }
    }
}

struct CharacterError {
    let position: Int
    let inputChar: Character
    let targetChar: Character?
    let errorType: ErrorType
    
    var displayText: String {
        if let target = targetChar {
            return "'\(inputChar)' → '\(target)'"
        } else {
            return "Extra: '\(inputChar)'"
        }
    }
}

struct DetailedErrorAnalysis {
    let totalErrors: Int
    let accuracy: Double
    let completionRate: Double
    let errorBreakdown: [ErrorType: Int]
    let characterErrors: [CharacterError]
    let mostCommonErrors: [ErrorType]
    let suggestions: [String]
    
    var hasErrors: Bool { totalErrors > 0 }
    var errorRate: Double { 100.0 - accuracy }
}

// MVP: Basic highlight colors (3 colors only)
enum BasicHighlightColor: String, CaseIterable {
    case correct = "#34C759"    // Green: correct part
    case incorrect = "#FF3B30"  // Red: incorrect part
    case pending = "#8E8E93"    // Gray: uninput part
    
    var displayName: String {
        switch self {
        case .correct: return "Correct"
        case .incorrect: return "Incorrect"
        case .pending: return "Pending"
        }
    }
}