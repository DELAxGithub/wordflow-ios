//
//  PersonalBestManager.swift
//  Wordflow - Personal Best Records Manager
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation

/// 自己ベスト記録の高速キャッシュ管理
final class PersonalBestManager {
    
    // MARK: - Constants
    
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "TimeAttack_PersonalBest_"
    private let datePrefix = "TimeAttack_BestDate_"
    private let accuracyPrefix = "TimeAttack_BestAccuracy_"
    
    // MARK: - Public Methods
    
    /// 自己ベストタイム取得
    func getPersonalBest(for taskId: UUID) -> PersonalBestRecord? {
        let timeKey = keyPrefix + taskId.uuidString
        let dateKey = datePrefix + taskId.uuidString
        let accuracyKey = accuracyPrefix + taskId.uuidString
        
        let time = userDefaults.double(forKey: timeKey)
        guard time > 0 else { return nil }
        
        let date = userDefaults.object(forKey: dateKey) as? Date ?? Date()
        let accuracy = userDefaults.double(forKey: accuracyKey)
        
        return PersonalBestRecord(
            taskId: taskId,
            bestTime: time,
            achievedAt: date,
            accuracy: accuracy
        )
    }
    
    /// 自己ベスト更新
    func updatePersonalBest(for taskId: UUID, time: TimeInterval, 
                          accuracy: Double = 0.0, date: Date = Date()) {
        let timeKey = keyPrefix + taskId.uuidString
        let dateKey = datePrefix + taskId.uuidString
        let accuracyKey = accuracyPrefix + taskId.uuidString
        
        userDefaults.set(time, forKey: timeKey)
        userDefaults.set(date, forKey: dateKey)
        userDefaults.set(accuracy, forKey: accuracyKey)
    }
    
    /// 特定タスクの記録削除
    func clearPersonalBest(for taskId: UUID) {
        let timeKey = keyPrefix + taskId.uuidString
        let dateKey = datePrefix + taskId.uuidString
        let accuracyKey = accuracyPrefix + taskId.uuidString
        
        userDefaults.removeObject(forKey: timeKey)
        userDefaults.removeObject(forKey: dateKey)
        userDefaults.removeObject(forKey: accuracyKey)
    }
    
    /// 全記録削除
    func clearAllRecords() {
        let keys = userDefaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.hasPrefix(keyPrefix) || 
               key.hasPrefix(datePrefix) || 
               key.hasPrefix(accuracyPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// 全記録の統計情報
    func getOverallStats() -> OverallStats {
        let allRecords = getAllRecords()
        
        guard !allRecords.isEmpty else {
            return OverallStats(
                totalTasks: 0,
                averageBestTime: 0.0,
                fastestTime: 0.0,
                slowestTime: 0.0,
                averageAccuracy: 0.0,
                totalAttempts: 0
            )
        }
        
        let times = allRecords.map { $0.bestTime }
        let accuracies = allRecords.map { $0.accuracy }
        
        return OverallStats(
            totalTasks: allRecords.count,
            averageBestTime: times.reduce(0, +) / Double(times.count),
            fastestTime: times.min() ?? 0.0,
            slowestTime: times.max() ?? 0.0,
            averageAccuracy: accuracies.reduce(0, +) / Double(accuracies.count),
            totalAttempts: allRecords.count // 簡略化
        )
    }
    
    /// 新記録判定
    func isNewRecord(for taskId: UUID, time: TimeInterval) -> Bool {
        guard let currentBest = getPersonalBest(for: taskId) else {
            return true // 初回記録
        }
        return time < currentBest.bestTime
    }
    
    /// 改善時間計算
    func getImprovement(for taskId: UUID, time: TimeInterval) -> TimeInterval? {
        guard let currentBest = getPersonalBest(for: taskId) else {
            return nil // 比較対象なし
        }
        let improvement = currentBest.bestTime - time
        return improvement > 0 ? improvement : nil
    }
    
    // MARK: - Private Methods
    
    /// 全記録取得
    private func getAllRecords() -> [PersonalBestRecord] {
        let keys = userDefaults.dictionaryRepresentation().keys
        let taskIds = keys.compactMap { key -> UUID? in
            guard key.hasPrefix(keyPrefix) else { return nil }
            let uuidString = String(key.dropFirst(keyPrefix.count))
            return UUID(uuidString: uuidString)
        }
        
        return taskIds.compactMap { getPersonalBest(for: $0) }
    }
}

// MARK: - Supporting Types

/// 自己ベスト記録構造体
struct PersonalBestRecord {
    let taskId: UUID
    let bestTime: TimeInterval
    let achievedAt: Date
    let accuracy: Double
    
    var formattedTime: String {
        let minutes = Int(bestTime) / 60
        let seconds = bestTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: achievedAt)
    }
    
    var formattedAccuracy: String {
        return String(format: "%.1f%%", accuracy)
    }
    
    /// パフォーマンスレーティング
    var performanceRating: String {
        let timeScore = calculateTimeScore()
        let accuracyScore = accuracy / 100.0
        let totalScore = (timeScore + accuracyScore) / 2.0
        
        switch totalScore {
        case 0.9...: return "Excellent"
        case 0.8..<0.9: return "Great"
        case 0.7..<0.8: return "Good"
        case 0.6..<0.7: return "Fair"
        default: return "Needs improvement"
        }
    }
    
    /// 時間スコア計算（簡略版）
    private func calculateTimeScore() -> Double {
        // 基準：60秒で満点、120秒で50点
        let maxTime: TimeInterval = 120.0
        let optimalTime: TimeInterval = 60.0
        
        if bestTime <= optimalTime {
            return 1.0
        } else if bestTime >= maxTime {
            return 0.5
        } else {
            return 1.0 - (bestTime - optimalTime) / (maxTime - optimalTime) * 0.5
        }
    }
}

/// 全体統計構造体
struct OverallStats {
    let totalTasks: Int
    let averageBestTime: TimeInterval
    let fastestTime: TimeInterval
    let slowestTime: TimeInterval
    let averageAccuracy: Double
    let totalAttempts: Int
    
    var formattedAverageBestTime: String {
        let minutes = Int(averageBestTime) / 60
        let seconds = averageBestTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var formattedFastestTime: String {
        let minutes = Int(fastestTime) / 60
        let seconds = fastestTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var formattedSlowestTime: String {
        let minutes = Int(slowestTime) / 60
        let seconds = slowestTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var hasData: Bool {
        return totalTasks > 0
    }
    
    /// 全体パフォーマンス評価
    var overallRating: String {
        guard hasData else { return "No data" }
        
        let avgTimeScore = calculateTimeScore(for: averageBestTime)
        let accuracyScore = averageAccuracy / 100.0
        let totalScore = (avgTimeScore + accuracyScore) / 2.0
        
        switch totalScore {
        case 0.9...: return "Excellent Typist"
        case 0.8..<0.9: return "Advanced"
        case 0.7..<0.8: return "Intermediate"
        case 0.6..<0.7: return "Beginner"
        default: return "Learning"
        }
    }
    
    private func calculateTimeScore(for time: TimeInterval) -> Double {
        let maxTime: TimeInterval = 120.0
        let optimalTime: TimeInterval = 60.0
        
        if time <= optimalTime {
            return 1.0
        } else if time >= maxTime {
            return 0.5
        } else {
            return 1.0 - (time - optimalTime) / (maxTime - optimalTime) * 0.5
        }
    }
}