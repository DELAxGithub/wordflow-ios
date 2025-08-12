//
//  TimeAttackResultRepository.swift
//  Wordflow - Time Attack Results Repository
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation
import SwiftData

@MainActor
final class TimeAttackResultRepository: ObservableObject {
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// 新しいTime Attack結果を保存
    func saveResult(_ result: TimeAttackResult) -> Bool {
        guard let modelContext = modelContext else {
            print("ModelContext not available")
            return false
        }
        
        do {
            // データ検証
            let validationErrors = result.validate()
            if !validationErrors.isEmpty {
                print("Validation errors: \(validationErrors)")
                result.autoCorrect()
            }
            
            modelContext.insert(result)
            try modelContext.save()
            return true
        } catch {
            print("Failed to save TimeAttackResult: \(error)")
            return false
        }
    }
    
    /// 既存結果の更新
    func updateResult(_ result: TimeAttackResult) -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            try modelContext.save()
            return true
        } catch {
            print("Failed to update TimeAttackResult: \(error)")
            return false
        }
    }
    
    /// 結果削除
    func deleteResult(_ result: TimeAttackResult) -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            modelContext.delete(result)
            try modelContext.save()
            return true
        } catch {
            print("Failed to delete TimeAttackResult: \(error)")
            return false
        }
    }
    
    // MARK: - Query Methods
    
    /// 全Time Attack結果取得
    func fetchAllResults() -> [TimeAttackResult] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<TimeAttackResult>(
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all TimeAttackResults: \(error)")
            return []
        }
    }
    
    /// 特定タスクの結果取得
    func fetchResultsForTask(_ task: IELTSTask) -> [TimeAttackResult] {
        guard let modelContext = modelContext else { return [] }
        
        let taskId = task.id
        let descriptor = FetchDescriptor<TimeAttackResult>(
            predicate: #Predicate { $0.task?.id == taskId },
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch TimeAttackResults for task: \(error)")
            return []
        }
    }
    
    /// 自己ベスト記録取得
    func fetchBestResultForTask(_ task: IELTSTask) -> TimeAttackResult? {
        guard let modelContext = modelContext else { return nil }
        
        let taskId = task.id
        var descriptor = FetchDescriptor<TimeAttackResult>(
            predicate: #Predicate { result in
                result.task?.id == taskId && result.isPersonalBest == true
            },
            sortBy: [SortDescriptor(\.completionTime, order: .forward)]
        )
        descriptor.fetchLimit = 1
        
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Failed to fetch best result: \(error)")
            return nil
        }
    }
    
    /// 最近の記録取得
    func fetchRecentResults(limit: Int = 10) -> [TimeAttackResult] {
        guard let modelContext = modelContext else { return [] }
        
        var descriptor = FetchDescriptor<TimeAttackResult>(
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch recent results: \(error)")
            return []
        }
    }
    
    /// 今日の記録取得
    func fetchTodayResults() -> [TimeAttackResult] {
        guard let modelContext = modelContext else { return [] }
        
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<TimeAttackResult>(
            predicate: #Predicate { result in
                result.achievedAt >= startOfDay && result.achievedAt < endOfDay
            },
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's results: \(error)")
            return []
        }
    }
    
    // MARK: - Analytics Methods
    
    /// タスク別統計取得
    func fetchStatistics(for task: IELTSTask) -> TimeAttackStatistics {
        let results = fetchResultsForTask(task)
        
        guard !results.isEmpty else {
            return TimeAttackStatistics.empty
        }
        
        let times = results.map { $0.completionTime }
        let accuracies = results.map { $0.finalAccuracy }
        let corrections = results.map { $0.correctionCost }
        
        return TimeAttackStatistics(
            attemptCount: results.count,
            bestTime: times.min()!,
            worstTime: times.max()!,
            averageTime: times.reduce(0, +) / Double(times.count),
            bestAccuracy: accuracies.max()!,
            averageAccuracy: accuracies.reduce(0, +) / Double(accuracies.count),
            averageCorrections: Double(corrections.reduce(0, +)) / Double(corrections.count),
            personalBestCount: results.filter { $0.isPersonalBest }.count,
            totalBadges: results.flatMap { $0.badges }.count,
            lastAttempt: results.first?.achievedAt
        )
    }
    
    /// 全体的なランキング取得
    func fetchGlobalRankings(limit: Int = 100) -> [TimeAttackResult] {
        guard let modelContext = modelContext else { return [] }
        
        var descriptor = FetchDescriptor<TimeAttackResult>(
            predicate: #Predicate { $0.isPersonalBest == true },
            sortBy: [SortDescriptor(\.completionTime, order: .forward)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch rankings: \(error)")
            return []
        }
    }
    
    // MARK: - Export Methods
    
    /// CSV形式でエクスポート
    func exportToCSV(includeAllAttempts: Bool = false) -> String {
        let results = includeAllAttempts ? fetchAllResults() : 
                     fetchAllResults().filter { $0.isPersonalBest }
        
        var csv = TimeAttackResult.csvHeader() + "\n"
        
        for result in results {
            csv += result.toCsvRow() + "\n"
        }
        
        return csv
    }
    
    /// JSON形式でエクスポート
    func exportToJSON() -> Data? {
        let results = fetchAllResults()
        
        let exportData = results.map { result in
            TimeAttackExportData(
                id: result.id,
                taskId: result.task?.id,
                completionTime: result.completionTime,
                accuracy: result.finalAccuracy,
                correctionCost: result.correctionCost,
                achievedAt: result.achievedAt,
                isPersonalBest: result.isPersonalBest,
                badges: result.badges.map { $0.rawValue },
                grade: result.performanceGrade
            )
        }
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            print("Failed to export JSON: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

/// Time Attack統計情報
struct TimeAttackStatistics {
    let attemptCount: Int
    let bestTime: TimeInterval
    let worstTime: TimeInterval
    let averageTime: TimeInterval
    let bestAccuracy: Double
    let averageAccuracy: Double
    let averageCorrections: Double
    let personalBestCount: Int
    let totalBadges: Int
    let lastAttempt: Date?
    
    static let empty = TimeAttackStatistics(
        attemptCount: 0, bestTime: 0, worstTime: 0, averageTime: 0,
        bestAccuracy: 0, averageAccuracy: 0, averageCorrections: 0,
        personalBestCount: 0, totalBadges: 0, lastAttempt: nil
    )
}

/// エクスポート用データ構造
struct TimeAttackExportData: Codable {
    let id: UUID
    let taskId: UUID?
    let completionTime: TimeInterval
    let accuracy: Double
    let correctionCost: Int
    let achievedAt: Date
    let isPersonalBest: Bool
    let badges: [String]
    let grade: String
}