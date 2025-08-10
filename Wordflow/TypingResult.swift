//
//  TypingResult.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import SwiftData

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
    }
    
    // Export to CSV format
    func toCsvRow() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        return [
            dateFormatter.string(from: sessionDate),
            task?.taskType.shortName ?? "Unknown",
            String(format: "%.1f", finalWPM),
            String(format: "%.1f", accuracy),
            String(format: "%.1f", completionPercentage),
            String(basicErrorCount),
            String(format: "%.1f", testDuration)
        ].joined(separator: ",")
    }
}