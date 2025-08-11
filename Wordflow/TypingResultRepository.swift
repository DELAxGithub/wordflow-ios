//
//  TypingResultRepository.swift
//  Wordflow - Typing Practice App
//

import Foundation
import SwiftData

@MainActor
final class TypingResultRepository: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAllResults() -> [TypingResult] {
        let descriptor = FetchDescriptor<TypingResult>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch typing results: \(error)")
            return []
        }
    }
    
    func fetchResultsForTask(_ task: IELTSTask) -> [TypingResult] {
        let taskId = task.id
        let descriptor = FetchDescriptor<TypingResult>(
            predicate: #Predicate { $0.task?.id == taskId },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch results for task: \(error)")
            return []
        }
    }
    
    func fetchRecentResults(limit: Int = 10) -> [TypingResult] {
        var descriptor = FetchDescriptor<TypingResult>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch recent results: \(error)")
            return []
        }
    }
    
    func saveResult(_ result: TypingResult) {
        do {
            modelContext.insert(result)
            try modelContext.save()
        } catch {
            print("Failed to save typing result: \(error)")
        }
    }
    
    func deleteResult(_ result: TypingResult) {
        do {
            modelContext.delete(result)
            try modelContext.save()
        } catch {
            print("Failed to delete result: \(error)")
        }
    }
    
    // 今日の記録を取得
    func fetchTodayResults() -> [TypingResult] {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<TypingResult>(
            predicate: #Predicate { result in 
                result.sessionDate >= startOfDay && result.sessionDate < endOfDay
            },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's results: \(error)")
            return []
        }
    }
    
    // 特定のタイマーモードでの今日のベスト記録を取得
    func getBestResultForTimerMode(_ timerMode: TimerMode) -> TypingResult? {
        let todayResults = fetchTodayResults()
        let timerModeString = getTimerModeString(from: timerMode)
        return todayResults
            .filter { $0.timerModeString == timerModeString }
            .max { $0.netWPM < $1.netWPM }
    }
    
    // 特定のタイマーモードでの前回記録を取得（今回を除く直近）
    func getPreviousResultForTimerMode(_ timerMode: TimerMode, excluding currentResult: TypingResult) -> TypingResult? {
        let todayResults = fetchTodayResults()
        let timerModeString = getTimerModeString(from: timerMode)
        return todayResults
            .filter { $0.timerModeString == timerModeString && $0.id != currentResult.id }
            .first // 最新（前回）の記録
    }
    
    // TimerModeからtimerModeStringへの変換ヘルパー
    private func getTimerModeString(from timerMode: TimerMode) -> String {
        switch timerMode {
        case .exam:
            return "exam"
        case .practice(let duration):
            return "practice(\(Int(duration))s)"
        }
    }
    
    // Export results to CSV
    func exportToCSV() -> String {
        let results = fetchAllResults()
        
        var csv = "Date,Task Type,WPM,Accuracy,Completion,Errors,Duration\n"
        
        for result in results {
            csv += result.toCsvRow() + "\n"
        }
        
        return csv
    }
}