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
        
        var segments: [TextSegment] = []
        var correctChars = 0
        let totalTyped = inputChars.count
        
        let maxLength = max(targetChars.count, inputChars.count)
        
        for i in 0..<maxLength {
            let targetChar = i < targetChars.count ? targetChars[i] : nil
            let inputChar = i < inputChars.count ? inputChars[i] : nil
            
            switch (targetChar, inputChar) {
            case let (target?, input?) where target == input:
                // Correct character
                segments.append(TextSegment(
                    text: String(target),
                    color: .green,
                    backgroundColor: Color.green.opacity(0.1),
                    isBold: false
                ))
                correctChars += 1
                
            case let (_, input?):
                // Incorrect character
                segments.append(TextSegment(
                    text: String(input),
                    color: .white,
                    backgroundColor: .red,
                    isBold: true
                ))
                
            case let (target?, nil):
                // Not yet typed
                segments.append(TextSegment(
                    text: String(target),
                    color: .secondary,
                    backgroundColor: Color.clear,
                    isBold: false
                ))
                
            case (nil, let input?):
                // Extra characters (shouldn't happen in normal typing)
                segments.append(TextSegment(
                    text: String(input),
                    color: .white,
                    backgroundColor: .red,
                    isBold: true
                ))
                
            case (nil, nil):
                // Both nil - shouldn't happen in our loop
                break
            }
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