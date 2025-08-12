//
//  AchievementBadge.swift
//  Wordflow - Time Attack Mode
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation

/// Time Attack Mode で獲得可能な称号システム
enum AchievementBadge: String, CaseIterable, Codable {
    // MARK: - Speed Achievements
    case speedDemon = "speed_demon"           // 大幅な記録更新
    case lightning = "lightning"              // 非常に早い完了
    case flashFinish = "flash_finish"         // 1分以内完了
    case recordBreaker = "record_breaker"     // 記録更新
    
    // MARK: - Accuracy Achievements  
    case perfectionist = "perfectionist"     // 100% 正確性
    case sharpshooter = "sharpshooter"       // 98%+ 正確性
    case steadyHands = "steady_hands"        // 95%+ 正確性
    
    // MARK: - Efficiency Achievements
    case flawless = "flawless"               // 修正0回
    case efficient = "efficient"             // 修正2回以下
    case oneShot = "one_shot"                // 初回で高スコア
    
    // MARK: - Consistency Achievements
    case hotStreak = "hot_streak"            // 連続記録更新
    case consistent = "consistent"           // 安定したパフォーマンス
    case improved = "improved"               // 前回より改善
    
    // MARK: - Special Achievements
    case firstTimer = "first_timer"          // 初回完了
    case persistent = "persistent"           // 多数回挑戦
    case champion = "champion"               // 総合的に優秀
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .speedDemon: return "Speed Demon"
        case .lightning: return "Lightning"
        case .flashFinish: return "Flash Finish"
        case .recordBreaker: return "Record Breaker"
        case .perfectionist: return "Perfectionist"
        case .sharpshooter: return "Sharpshooter"
        case .steadyHands: return "Steady Hands"
        case .flawless: return "Flawless"
        case .efficient: return "Efficient"
        case .oneShot: return "One Shot"
        case .hotStreak: return "Hot Streak"
        case .consistent: return "Consistent"
        case .improved: return "Improved"
        case .firstTimer: return "First Timer"
        case .persistent: return "Persistent"
        case .champion: return "Champion"
        }
    }
    
    var description: String {
        switch self {
        case .speedDemon: return "大幅な記録更新を達成"
        case .lightning: return "電光石火の速さで完了"
        case .flashFinish: return "1分以内で完了"
        case .recordBreaker: return "自己ベストを更新"
        case .perfectionist: return "100% 正確性を達成"
        case .sharpshooter: return "98%以上の正確性を達成"
        case .steadyHands: return "95%以上の正確性を達成"
        case .flawless: return "修正なしで完了"
        case .efficient: return "効率的な入力を実現"
        case .oneShot: return "初回で高スコアを獲得"
        case .hotStreak: return "連続で記録を更新"
        case .consistent: return "安定したパフォーマンス"
        case .improved: return "前回より改善"
        case .firstTimer: return "初回完了おめでとう"
        case .persistent: return "継続は力なり"
        case .champion: return "総合チャンピオン"
        }
    }
    
    var iconName: String {
        switch self {
        case .speedDemon: return "flame.fill"
        case .lightning: return "bolt.fill"
        case .flashFinish: return "timer"
        case .recordBreaker: return "trophy.fill"
        case .perfectionist: return "star.fill"
        case .sharpshooter: return "target"
        case .steadyHands: return "hand.raised.fill"
        case .flawless: return "checkmark.seal.fill"
        case .efficient: return "gearshape.fill"
        case .oneShot: return "bullseye"
        case .hotStreak: return "flame"
        case .consistent: return "chart.line.uptrend.xyaxis"
        case .improved: return "arrow.up.circle.fill"
        case .firstTimer: return "rosette"
        case .persistent: return "mountain.2.fill"
        case .champion: return "crown.fill"
        }
    }
    
    var color: String {
        switch self {
        case .speedDemon, .lightning, .flashFinish: return "orange"
        case .recordBreaker, .champion: return "gold"
        case .perfectionist, .sharpshooter, .steadyHands: return "green"
        case .flawless, .efficient, .oneShot: return "blue"
        case .hotStreak, .consistent, .improved: return "purple"
        case .firstTimer, .persistent: return "gray"
        }
    }
    
    // MARK: - Achievement Logic
    
    /// 記録に基づいて獲得すべき称号を判定
    static func evaluateAchievements(for result: TimeAttackResult, 
                                   previousBest: TimeAttackResult?,
                                   allResults: [TimeAttackResult]) -> [AchievementBadge] {
        var achievements: [AchievementBadge] = []
        
        // First Timer
        if allResults.isEmpty {
            achievements.append(.firstTimer)
        }
        
        // Record Breaker / Personal Best
        if result.isPersonalBest {
            achievements.append(.recordBreaker)
            
            // Speed Demon (10秒以上の改善)
            if let previous = previousBest, 
               (previous.completionTime - result.completionTime) >= 10.0 {
                achievements.append(.speedDemon)
            }
        }
        
        // Lightning / Flash Finish
        if result.completionTime <= 60.0 {
            achievements.append(.flashFinish)
        }
        if result.completionTime <= 45.0 {
            achievements.append(.lightning)
        }
        
        // Accuracy Achievements
        if result.finalAccuracy == 100.0 {
            achievements.append(.perfectionist)
        } else if result.finalAccuracy >= 98.0 {
            achievements.append(.sharpshooter)
        } else if result.finalAccuracy >= 95.0 {
            achievements.append(.steadyHands)
        }
        
        // Efficiency Achievements
        if result.correctionCost == 0 {
            achievements.append(.flawless)
        } else if result.correctionCost <= 2 {
            achievements.append(.efficient)
        }
        
        // One Shot (初回で高スコア)
        if allResults.isEmpty && result.performanceGrade.hasPrefix("A") {
            achievements.append(.oneShot)
        }
        
        // Hot Streak (連続記録更新)
        let recentResults = allResults.suffix(3)
        if recentResults.allSatisfy({ $0.isPersonalBest }) && recentResults.count >= 3 {
            achievements.append(.hotStreak)
        }
        
        // Improved (前回より改善)
        if let improvementTime = result.improvementTime, improvementTime > 0 {
            achievements.append(.improved)
        }
        
        // Persistent (10回以上挑戦)
        if allResults.count >= 10 {
            achievements.append(.persistent)
        }
        
        // Champion (総合的に優秀)
        if result.performanceGrade == "A+" && result.finalAccuracy >= 98.0 && result.correctionCost <= 1 {
            achievements.append(.champion)
        }
        
        return achievements
    }
}