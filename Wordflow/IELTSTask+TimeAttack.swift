//
//  IELTSTask+TimeAttack.swift  
//  Wordflow - Time Attack Mode Extensions
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation
import SwiftData

extension IELTSTask {
    // MARK: - Time Attack Computed Properties
    
    /// 最速記録（自己ベスト）
    var bestTimeAttackTime: TimeInterval? {
        return timeAttackResults
            .filter { $0.isPersonalBest }
            .map { $0.completionTime }
            .min()
    }
    
    /// Time Attack挑戦回数
    var timeAttackAttempts: Int {
        return timeAttackResults.count
    }
    
    /// 平均完了時間
    var averageTimeAttackTime: TimeInterval {
        guard !timeAttackResults.isEmpty else { return 0.0 }
        let total = timeAttackResults.reduce(0.0) { $0 + $1.completionTime }
        return total / Double(timeAttackResults.count)
    }
    
    /// 最高正確性
    var bestTimeAttackAccuracy: Double {
        return timeAttackResults.map { $0.finalAccuracy }.max() ?? 0.0
    }
    
    /// Time Attack人気度（挑戦回数による）
    var timeAttackPopularity: Int {
        return timeAttackAttempts
    }
    
    /// 推奨難易度レベル
    var timeAttackDifficulty: TimeAttackDifficulty {
        let wordCount = self.wordCount
        let targetBand = self.targetBandScore
        
        switch (wordCount, targetBand) {
        case (0..<150, 0..<7.0):
            return .beginner
        case (150..<200, 7.0..<7.5):
            return .intermediate
        case (200..<250, 7.5..<8.0):
            return .advanced
        case (250..., 8.0...):
            return .expert
        default:
            return .intermediate
        }
    }
    
    /// Time Attack統計サマリー
    var timeAttackSummary: TimeAttackSummary {
        return TimeAttackSummary(
            attempts: timeAttackAttempts,
            bestTime: bestTimeAttackTime ?? 0.0,
            averageTime: averageTimeAttackTime,
            bestAccuracy: bestTimeAttackAccuracy,
            totalBadges: timeAttackResults.flatMap { $0.badges }.count,
            lastAttempt: timeAttackResults.max { $0.achievedAt < $1.achievedAt }?.achievedAt
        )
    }
    
}

/// Time Attack難易度レベル
enum TimeAttackDifficulty: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate" 
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初級"
        case .intermediate: return "中級"
        case .advanced: return "上級"
        case .expert: return "エキスパート"
        }
    }
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .expert: return "red"
        }
    }
    
    /// 推奨制限時間（秒）
    var recommendedTimeLimit: TimeInterval {
        switch self {
        case .beginner: return 120.0   // 2分
        case .intermediate: return 90.0 // 1分30秒
        case .advanced: return 75.0     // 1分15秒
        case .expert: return 60.0       // 1分
        }
    }
    
    /// 目標WPM
    var targetWPM: Double {
        switch self {
        case .beginner: return 30.0
        case .intermediate: return 45.0
        case .advanced: return 60.0
        case .expert: return 80.0
        }
    }
}

/// Time Attack統計サマリー構造体
struct TimeAttackSummary {
    let attempts: Int
    let bestTime: TimeInterval
    let averageTime: TimeInterval
    let bestAccuracy: Double
    let totalBadges: Int
    let lastAttempt: Date?
    
    var formattedBestTime: String {
        guard bestTime > 0 else { return "No record" }
        let minutes = Int(bestTime) / 60
        let seconds = bestTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var formattedAverageTime: String {
        guard averageTime > 0 else { return "No data" }
        let minutes = Int(averageTime) / 60
        let seconds = averageTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var hasAttempts: Bool {
        return attempts > 0
    }
    
    var performanceIndicator: String {
        guard hasAttempts else { return "No attempts" }
        
        if bestAccuracy >= 98.0 && bestTime <= 60.0 {
            return "Excellent"
        } else if bestAccuracy >= 95.0 && bestTime <= 90.0 {
            return "Good"
        } else if bestAccuracy >= 90.0 && bestTime <= 120.0 {
            return "Fair"
        } else {
            return "Needs improvement"
        }
    }
}

// MARK: - Time Attack Task Extensions for Repository
extension IELTSTask {
    /// Time Attack推奨タスク判定
    var isRecommendedForTimeAttack: Bool {
        // 適度な長さで、既存の記録がないか改善の余地があるタスク
        let isGoodLength = wordCount >= 100 && wordCount <= 300
        let hasNoRecord = bestTimeAttackTime == nil
        let hasRoomForImprovement = bestTimeAttackAccuracy < 95.0
        
        return isGoodLength && (hasNoRecord || hasRoomForImprovement)
    }
    
    /// Time Attack難易度スコア（0.0-1.0）
    var timeAttackDifficultyScore: Double {
        let lengthScore = min(1.0, Double(wordCount) / 250.0)
        let complexityScore = min(1.0, targetBandScore / 9.0)
        return (lengthScore + complexityScore) / 2.0
    }
}