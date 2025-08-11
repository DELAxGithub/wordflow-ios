//
//  TypingResult.swift
//  Wordflow - Typing Practice App
//

import Foundation
import SwiftData

// Helper extension for dictionary key mapping
extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}

@Model
final class TypingResult {
    @Attribute(.unique) var id: UUID
    var sessionDate: Date
    var testDuration: TimeInterval
    var targetText: String
    var userInput: String
    var finalWPM: Double
    var accuracy: Double
    var completionPercentage: Double
    var basicErrorCount: Int // Simplified: basic error count only
    
    // Phase A: New scoring metrics
    var grossWPM: Double
    var netWPM: Double
    var qualityScore: Double
    var errorBreakdownJSON: String // JSON serialized [ErrorType: Int]
    var timerModeString: String // "exam" or "practice(90s)" etc
    var matchedWords: Int
    var totalWords: Int
    
    @Relationship(deleteRule: .nullify)
    var task: IELTSTask?
    
    init(task: IELTSTask, userInput: String, duration: TimeInterval, wpm: Double, accuracy: Double, completion: Double, errors: Int) {
        self.id = UUID()
        self.task = task
        self.targetText = task.modelAnswer
        self.userInput = userInput
        self.sessionDate = Date()
        self.testDuration = duration
        self.finalWPM = wpm
        self.accuracy = accuracy
        self.completionPercentage = completion
        self.basicErrorCount = errors
        
        // Initialize new fields with legacy values
        self.grossWPM = wpm
        self.netWPM = wpm
        self.qualityScore = wpm * accuracy / 100.0
        self.errorBreakdownJSON = "{}"
        self.timerModeString = "legacy"
        self.matchedWords = 0
        self.totalWords = 0
    }
    
    // Phase A: New enhanced initializer
    init(task: IELTSTask, userInput: String, duration: TimeInterval, scoringResult: ScoringResult, timerMode: TimerMode) {
        self.id = UUID()
        self.task = task
        self.targetText = task.modelAnswer
        self.userInput = userInput
        self.sessionDate = Date()
        self.testDuration = duration
        
        // Legacy fields (for backward compatibility)
        self.finalWPM = scoringResult.netWPM
        self.accuracy = scoringResult.accuracy
        self.completionPercentage = scoringResult.completionPercentage
        self.basicErrorCount = scoringResult.basicErrorCount
        
        // Phase A: New scoring fields
        self.grossWPM = scoringResult.grossWPM
        self.netWPM = scoringResult.netWPM
        self.qualityScore = scoringResult.qualityScore
        self.matchedWords = scoringResult.matchedWords
        self.totalWords = scoringResult.totalWords
        
        // Serialize error breakdown to JSON (simplified - errorBreakdown is already [String: Int])
        if let jsonData = try? JSONSerialization.data(withJSONObject: scoringResult.errorBreakdown, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.errorBreakdownJSON = jsonString
        } else {
            self.errorBreakdownJSON = "{}"
        }
        
        // Serialize timer mode
        switch timerMode {
        case .exam:
            self.timerModeString = "exam"
        case .practice(let duration):
            self.timerModeString = "practice(\(Int(duration))s)"
        }
    }
    
    // Export to CSV format (Phase A enhanced)
    func toCsvRow() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        return [
            dateFormatter.string(from: sessionDate),
            task?.taskType.shortName ?? "Unknown",
            String(format: "%.1f", netWPM),
            String(format: "%.1f", grossWPM),
            String(format: "%.1f", accuracy),
            String(format: "%.1f", qualityScore),
            getErrorBreakdownString(),
            String(format: "%.1f", completionPercentage),
            String(basicErrorCount),
            String(format: "%.1f", testDuration),
            timerModeString
        ].joined(separator: ",")
    }
    
    // Helper methods for new fields (simplified to return [String: Int])
    func getErrorBreakdown() -> [String: Int] {
        guard let data = errorBreakdownJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            return [:]
        }
        return dict
    }
    
    private func getErrorBreakdownString() -> String {
        let breakdown = getErrorBreakdown()
        if breakdown.isEmpty {
            return "\"none\""
        }
        let parts = breakdown.map { key, value in
            "\(key):\(value)"
        }
        return "\"\(parts.joined(separator: ","))\""
    }
    
    // CSV Header (class method)
    static func csvHeader() -> String {
        return [
            "date",
            "lesson", 
            "net_wpm",
            "gross_wpm",
            "accuracy",
            "quality",
            "errors",
            "completion",
            "total_errors",
            "duration_sec",
            "mode"
        ].joined(separator: ",")
    }
}