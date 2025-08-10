//
//  ExportManager.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import SwiftUI
import AppKit

@MainActor
final class ExportManager: ObservableObject {
    
    func exportResultsToCSV(results: [TypingResult]) -> String {
        var csv = "Date,Time,Task Type,Topic,WPM,Accuracy (%),Completion (%),Errors,Duration (min),Target Words\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for result in results {
            let row = [
                dateFormatter.string(from: result.sessionDate),
                timeFormatter.string(from: result.sessionDate),
                result.task?.taskType.shortName ?? "Unknown",
                result.task?.topic ?? "Unknown",
                String(format: "%.1f", result.finalWPM),
                String(format: "%.1f", result.accuracy),
                String(format: "%.1f", result.completionPercentage),
                String(result.basicErrorCount),
                String(format: "%.1f", result.testDuration / 60.0),
                String(result.task?.targetWordCount ?? 0)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    func saveCSVToFile(csv: String, filename: String = "ielts_practice_results.csv") {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Practice Results"
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save CSV: \(error)")
            }
        }
    }
    
    func generateSummaryReport(results: [TypingResult]) -> String {
        guard !results.isEmpty else {
            return "No practice sessions found."
        }
        
        let totalSessions = results.count
        let avgWPM = results.map(\.finalWPM).reduce(0, +) / Double(totalSessions)
        let avgAccuracy = results.map(\.accuracy).reduce(0, +) / Double(totalSessions)
        let totalPracticeTime = results.map(\.testDuration).reduce(0, +) / 60.0 // minutes
        
        let task1Results = results.filter { $0.task?.taskType == .task1 }
        let task2Results = results.filter { $0.task?.taskType == .task2 }
        
        var report = """
        # IELTS Typing Practice Summary Report
        
        ## Overall Statistics
        - Total Sessions: \(totalSessions)
        - Average WPM: \(String(format: "%.1f", avgWPM))
        - Average Accuracy: \(String(format: "%.1f", avgAccuracy))%
        - Total Practice Time: \(String(format: "%.1f", totalPracticeTime)) minutes
        
        ## Task Breakdown
        - Task 1 Sessions: \(task1Results.count)
        - Task 2 Sessions: \(task2Results.count)
        
        """
        
        if !task1Results.isEmpty {
            let task1AvgWPM = task1Results.map(\.finalWPM).reduce(0, +) / Double(task1Results.count)
            let task1AvgAccuracy = task1Results.map(\.accuracy).reduce(0, +) / Double(task1Results.count)
            report += """
            
            ### Task 1 Performance
            - Average WPM: \(String(format: "%.1f", task1AvgWPM))
            - Average Accuracy: \(String(format: "%.1f", task1AvgAccuracy))%
            
            """
        }
        
        if !task2Results.isEmpty {
            let task2AvgWPM = task2Results.map(\.finalWPM).reduce(0, +) / Double(task2Results.count)
            let task2AvgAccuracy = task2Results.map(\.accuracy).reduce(0, +) / Double(task2Results.count)
            report += """
            
            ### Task 2 Performance
            - Average WPM: \(String(format: "%.1f", task2AvgWPM))
            - Average Accuracy: \(String(format: "%.1f", task2AvgAccuracy))%
            
            """
        }
        
        report += """
        
        ## Recent Sessions
        """
        
        for (index, result) in results.prefix(5).enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            report += """
            
            \(index + 1). \(dateFormatter.string(from: result.sessionDate))
               Task: \(result.task?.taskType.shortName ?? "Unknown") - \(result.task?.topic ?? "Unknown")
               WPM: \(String(format: "%.1f", result.finalWPM)) | Accuracy: \(String(format: "%.1f", result.accuracy))% | Completion: \(String(format: "%.1f", result.completionPercentage))%
            """
        }
        
        return report
    }
}