//
//  RealTimeTextComparisonView.swift
//  Wordflow - Real-time Text Comparison
//
//  Created by Claude Code on 2025/08/12.
//

import SwiftUI
import Foundation

/// Real-time text comparison view that highlights differences between target text and user input
struct RealTimeTextComparisonView: View {
    let targetText: String
    let userInput: String
    let showCursor: Bool
    
    @State private var comparisonResult: TextComparisonResult
    
    init(targetText: String, userInput: String, showCursor: Bool = true) {
        self.targetText = targetText
        self.userInput = userInput
        self.showCursor = showCursor
        self._comparisonResult = State(initialValue: TextComparisonLogic.compare(target: targetText, input: userInput))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comparison display
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    buildAttributedText()
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            
            // Progress indicator
            if !userInput.isEmpty {
                ProgressView(value: comparisonResult.progressPercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: comparisonResult.overallColor))
                    .background(Color.gray.opacity(0.3))
                
                HStack {
                    Text("Progress: \(Int(comparisonResult.progressPercentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Accuracy: \(Int(comparisonResult.accuracyPercentage))%")
                        .font(.caption)
                        .foregroundColor(comparisonResult.accuracyPercentage > 95 ? .green : 
                                        comparisonResult.accuracyPercentage > 80 ? .orange : .red)
                }
            }
        }
        .onChange(of: userInput) { _, newInput in
            updateComparison(newInput)
        }
        .onChange(of: targetText) { _, newTarget in
            updateComparison(userInput)
        }
    }
    
    private func updateComparison(_ input: String) {
        comparisonResult = TextComparisonLogic.compare(target: targetText, input: input)
    }
    
    private func buildAttributedText() -> Text {
        var result = Text("")
        
        for segment in comparisonResult.segments {
            let styledText = Text(segment.text)
                .foregroundColor(segment.color)
                .fontWeight(segment.isBold ? .bold : .regular)
            
            result = result + styledText
        }
        
        // Add cursor if needed
        if showCursor && !userInput.isEmpty {
            let cursor = Text("│")
                .foregroundColor(.blue)
                .fontWeight(.bold)
            result = result + cursor
        }
        
        return result
    }
}

// MARK: - Text Comparison Logic

struct TextComparisonLogic {
    static func compare(target: String, input: String) -> TextComparisonResult {
        let targetChars = Array(target)
        let inputChars = Array(input)
        
        // 🔧 FIXED: Use Global Alignment instead of simple index comparison
        let alignmentResult = performGlobalAlignment(inputChars, targetChars)
        
        var segments: [TextSegment] = []
        var correctChars = 0
        let totalTyped = inputChars.count
        
        // Build segments based on alignment operations
        var targetIndex = 0
        var inputIndex = 0
        
        for operation in alignmentResult.operations {
            switch operation.type {
            case .match:
                // Correct character - show green
                let char = targetChars[targetIndex]
                segments.append(TextSegment(
                    text: String(char),
                    color: .green,
                    backgroundColor: Color.green.opacity(0.1),
                    isBold: false
                ))
                correctChars += 1
                targetIndex += 1
                inputIndex += 1
                
            case .substitute:
                // Wrong character - show red with input character
                let inputChar = inputChars[inputIndex]
                segments.append(TextSegment(
                    text: String(inputChar),
                    color: .white,
                    backgroundColor: .red,
                    isBold: true
                ))
                targetIndex += 1
                inputIndex += 1
                
            case .insert:
                // Extra character in input - show red
                let inputChar = inputChars[inputIndex]
                segments.append(TextSegment(
                    text: String(inputChar),
                    color: .white,
                    backgroundColor: .red,
                    isBold: true
                ))
                inputIndex += 1
                
            case .delete:
                // Missing character - show gray (not yet typed)
                let targetChar = targetChars[targetIndex]
                segments.append(TextSegment(
                    text: String(targetChar),
                    color: .secondary,
                    backgroundColor: Color.clear,
                    isBold: false
                ))
                targetIndex += 1
            }
        }
        
        // Add remaining untyped characters
        while targetIndex < targetChars.count {
            let targetChar = targetChars[targetIndex]
            segments.append(TextSegment(
                text: String(targetChar),
                color: .secondary,
                backgroundColor: Color.clear,
                isBold: false
            ))
            targetIndex += 1
        }
        
        let progressPercentage = targetChars.count > 0 ? 
            Double(min(inputChars.count, targetChars.count)) / Double(targetChars.count) * 100.0 : 0.0
        
        let accuracyPercentage = totalTyped > 0 ? 
            Double(correctChars) / Double(totalTyped) * 100.0 : 100.0
        
        let overallColor: Color = accuracyPercentage > 95 ? .green : 
                                 accuracyPercentage > 80 ? .orange : .red
        
        return TextComparisonResult(
            segments: segments,
            progressPercentage: progressPercentage,
            accuracyPercentage: accuracyPercentage,
            overallColor: overallColor,
            correctCharacters: correctChars,
            totalTyped: totalTyped
        )
    }
    
    // 🔧 ULTRA-SAFE Global Alignment implementation with comprehensive bounds checking
    private static func performGlobalAlignment(_ input: [Character], _ target: [Character]) -> UIAlignmentResult {
        let inputCount = input.count
        let targetCount = target.count
        
        // 🔧 CRASH FIX: Handle edge cases immediately
        guard inputCount >= 0 && targetCount >= 0 else {
            print("⚠️ Invalid input/target counts: input=\(inputCount), target=\(targetCount)")
            return UIAlignmentResult(operations: [], unfixedErrors: 0)
        }
        
        // 🔧 Handle empty cases safely
        if inputCount == 0 && targetCount == 0 {
            return UIAlignmentResult(operations: [], unfixedErrors: 0)
        }
        
        if inputCount == 0 {
            // All characters are deletions
            let operations = (0..<targetCount).map { i in
                UIAlignmentOperation(type: .delete, inputIndex: 0, targetIndex: i)
            }
            return UIAlignmentResult(operations: operations, unfixedErrors: targetCount)
        }
        
        if targetCount == 0 {
            // All characters are insertions
            let operations = (0..<inputCount).map { i in
                UIAlignmentOperation(type: .insert, inputIndex: i, targetIndex: 0)
            }
            return UIAlignmentResult(operations: operations, unfixedErrors: inputCount)
        }
        
        // 🔧 SAFE: Create matrix with validated dimensions
        let matrixRows = inputCount + 1
        let matrixCols = targetCount + 1
        
        guard matrixRows > 0 && matrixCols > 0 && matrixRows <= 10000 && matrixCols <= 10000 else {
            print("⚠️ Matrix dimensions out of safe range: \(matrixRows)x\(matrixCols)")
            return UIAlignmentResult(operations: [], unfixedErrors: max(inputCount, targetCount))
        }
        
        var dp = Array(repeating: Array(repeating: 0, count: matrixCols), count: matrixRows)
        
        // 🔧 SAFE: Initialize base cases with bounds checking
        for i in 0..<matrixRows {
            guard i < dp.count else { break }
            dp[i][0] = i
        }
        for j in 0..<matrixCols {
            guard j < dp[0].count else { break }
            dp[0][j] = j
        }
        
        // 🔧 SAFE: Fill the matrix with comprehensive bounds checking
        for i in 1..<matrixRows {
            for j in 1..<matrixCols {
                // Triple check bounds before array access
                guard i < dp.count && j < dp[i].count &&
                      i-1 < dp.count && j-1 < dp[i-1].count &&
                      i-1 < input.count && j-1 < target.count else {
                    print("⚠️ Matrix bounds error at i=\(i), j=\(j)")
                    continue
                }
                
                let matchCost = input[i-1] == target[j-1] ? 0 : 1
                dp[i][j] = min(
                    dp[i-1][j] + 1,     // Insert
                    dp[i][j-1] + 1,     // Delete
                    dp[i-1][j-1] + matchCost // Match/Substitute
                )
            }
        }
        
        // 🔧 SAFE: Backtrack with bounds checking
        var operations: [UIAlignmentOperation] = []
        var i = inputCount
        var j = targetCount
        var safetyCounter = 0
        let maxOperations = (inputCount + targetCount) * 2 // Safety limit
        
        while (i > 0 || j > 0) && safetyCounter < maxOperations {
            safetyCounter += 1
            
            // Comprehensive bounds checking
            guard i >= 0 && j >= 0 && i < dp.count && j < dp[0].count else {
                print("⚠️ Backtrack bounds error: i=\(i), j=\(j)")
                break
            }
            
            if i > 0 && j > 0 && i-1 < input.count && j-1 < target.count &&
               i-1 >= 0 && j-1 >= 0 && i-1 < dp.count && j-1 < dp[0].count {
                let matchCost = input[i-1] == target[j-1] ? 0 : 1
                if dp[i][j] == dp[i-1][j-1] + matchCost {
                    // Match or substitute
                    operations.insert(UIAlignmentOperation(
                        type: input[i-1] == target[j-1] ? .match : .substitute,
                        inputIndex: i-1,
                        targetIndex: j-1
                    ), at: 0)
                    i -= 1
                    j -= 1
                    continue
                }
            }
            
            if i > 0 && i-1 >= 0 && i-1 < dp.count && j < dp[i-1].count {
                if dp[i][j] == dp[i-1][j] + 1 {
                    // Insert
                    operations.insert(UIAlignmentOperation(
                        type: .insert,
                        inputIndex: i-1,
                        targetIndex: j
                    ), at: 0)
                    i -= 1
                    continue
                }
            }
            
            if j > 0 && j-1 >= 0 && i < dp.count && j-1 < dp[i].count {
                // Delete
                operations.insert(UIAlignmentOperation(
                    type: .delete,
                    inputIndex: i,
                    targetIndex: j-1
                ), at: 0)
                j -= 1
                continue
            }
            
            // Fallback - should never reach here
            print("⚠️ Backtrack fallback at i=\(i), j=\(j)")
            break
        }
        
        if safetyCounter >= maxOperations {
            print("⚠️ Backtrack safety limit reached")
        }
        
        return UIAlignmentResult(
            operations: operations,
            unfixedErrors: operations.filter { $0.type != .match }.count
        )
    }
}

// MARK: - Supporting Types

struct TextComparisonResult {
    let segments: [TextSegment]
    let progressPercentage: Double
    let accuracyPercentage: Double
    let overallColor: Color
    let correctCharacters: Int
    let totalTyped: Int
}

struct TextSegment {
    let text: String
    let color: Color
    let backgroundColor: Color
    let isBold: Bool
}

// MARK: - UI Specific Alignment Types (lightweight for display)

struct UIAlignmentOperation {
    let type: UIAlignmentOperationType
    let inputIndex: Int
    let targetIndex: Int
}

enum UIAlignmentOperationType {
    case match      // Correct character
    case substitute // Wrong character
    case insert     // Extra character in input
    case delete     // Missing character from target
}

struct UIAlignmentResult {
    let operations: [UIAlignmentOperation]
    let unfixedErrors: Int
}

// MARK: - Preview

#Preview {
    VStack {
        RealTimeTextComparisonView(
            targetText: "The quick brown fox jumps over the lazy dog.",
            userInput: "The quikc brown fox jums"
        )
        .padding()
    }
    .frame(width: 600, height: 400)
}