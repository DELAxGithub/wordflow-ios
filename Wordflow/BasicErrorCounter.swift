//
//  BasicErrorCounter.swift
//  Wordflow - Typing Practice App
//

import Foundation

// MVP: Greatly simplified error detection
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
}

struct BasicErrorInfo {
    let totalErrors: Int
    let errorRate: Double
    let errorPositions: [Int]
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