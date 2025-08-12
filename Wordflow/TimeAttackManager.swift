//
//  TimeAttackManager.swift
//  Wordflow - Time Attack Mode Manager
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class TimeAttackManager {
    
    // MARK: - Dependencies
    
    private let typingTestManager: TypingTestManager
    private let timeAttackRepository: TimeAttackResultRepository
    private let personalBestManager: PersonalBestManager
    
    // MARK: - State Properties
    
    private(set) var isActive: Bool = false
    private(set) var currentTask: IELTSTask?
    private(set) var personalBest: TimeAttackResult?
    private(set) var previousAttempt: TimeAttackResult?
    private(set) var allAttempts: [TimeAttackResult] = []
    
    // MARK: - Session Properties
    
    private(set) var currentResult: TimeAttackResult?
    private(set) var isNewRecord: Bool = false
    private(set) var achievedBadges: [AchievementBadge] = []
    private(set) var sessionStartTime: Date = Date()
    private var retryCount: Int = 0
    
    // MARK: - Current Session Stats (Read-only)
    
    var currentTime: TimeInterval {
        return typingTestManager.elapsedTime
    }
    
    var currentCorrectionCost: Int {
        return typingTestManager.correctionCost
    }
    
    var estimatedCompletionTime: TimeInterval? {
        guard let task = currentTask,
              typingTestManager.isTimeAttackMode,
              !typingTestManager.userInput.isEmpty else { return nil }
        
        let progress = Double(typingTestManager.userInput.count) / Double(task.modelAnswer.count)
        guard progress > 0.1 else { return nil } // 最低10%完了していること
        
        return typingTestManager.elapsedTime / progress
    }
    
    // MARK: - Initialization
    
    init(typingTestManager: TypingTestManager, 
         repository: TimeAttackResultRepository,
         personalBestManager: PersonalBestManager) {
        self.typingTestManager = typingTestManager
        self.timeAttackRepository = repository
        self.personalBestManager = personalBestManager
        
        // Time Attack 完了ハンドラーの設定
        typingTestManager.onTimeAttackCompleted = { [weak self] result in
            self?.handleTimeAttackCompletion(result)
        }
    }
    
    // MARK: - Public Methods
    
    /// Time Attack セッション開始
    func startTimeAttack(with task: IELTSTask) {
        guard !isActive else { return }
        
        currentTask = task
        isActive = true
        sessionStartTime = Date()
        isNewRecord = false
        achievedBadges = []
        
        // 既存記録の読み込み
        loadExistingRecords(for: task)
        
        // TypingTestManager にTime Attack開始を委譲
        typingTestManager.startTimeAttack(with: task)
    }
    
    /// Time Attack セッション中断
    func abortTimeAttack() {
        guard isActive else { return }
        
        typingTestManager.abortTimeAttack()
        resetSession()
    }
    
    /// 同一タスクでのリトライ
    func retryCurrentTask() {
        guard let task = currentTask else { return }
        retryCount += 1
        startTimeAttack(with: task)
    }
    
    /// 別のタスクに切り替え
    func switchToTask(_ newTask: IELTSTask) {
        if isActive {
            abortTimeAttack()
        }
        retryCount = 0
        startTimeAttack(with: newTask)
    }
    
    /// 入力更新（UI から呼ばれる）
    func updateInput(_ input: String) {
        typingTestManager.updateTimeAttackInput(input)
    }
    
    // MARK: - Private Methods
    
    /// 既存記録読み込み
    private func loadExistingRecords(for task: IELTSTask) {
        allAttempts = timeAttackRepository.fetchResultsForTask(task)
        personalBest = timeAttackRepository.fetchBestResultForTask(task)
        previousAttempt = allAttempts.last
    }
    
    /// Time Attack 完了処理
    private func handleTimeAttackCompletion(_ result: TimeAttackResult) {
        guard let task = currentTask else { return }
        
        currentResult = result
        
        // 改善時間計算
        if let previous = previousAttempt {
            result.improvementTime = previous.completionTime - result.completionTime
        }
        
        // 再試行回数設定
        result.retryCount = retryCount
        
        // 自己ベスト判定
        checkAndUpdatePersonalBest(result)
        
        // 称号評価
        evaluateAchievements(result)
        
        // データベース保存
        let success = timeAttackRepository.saveResult(result)
        if success {
            // UserDefaults キャッシュ更新
            if result.isPersonalBest {
                personalBestManager.updatePersonalBest(
                    for: task.id, 
                    time: result.completionTime,
                    accuracy: result.finalAccuracy,
                    date: result.achievedAt
                )
            }
            
            // 記録リストの更新
            allAttempts.append(result)
        }
        
        // セッション完了
        isActive = false
    }
    
    /// 自己ベスト判定・更新
    private func checkAndUpdatePersonalBest(_ result: TimeAttackResult) {
        if let currentBest = personalBest {
            // 新記録判定（完了時間 + 正確性を考慮）
            let isNewTime = result.completionTime < currentBest.completionTime
            let isSufficientAccuracy = result.finalAccuracy >= 95.0
            
            if isNewTime && isSufficientAccuracy {
                // 既存のベストフラグを無効化
                currentBest.isPersonalBest = false
                _ = timeAttackRepository.updateResult(currentBest)
                
                // 新しいベスト設定
                result.isPersonalBest = true
                personalBest = result
                isNewRecord = true
            }
        } else {
            // 初回記録
            result.isPersonalBest = true
            personalBest = result
            isNewRecord = true
        }
    }
    
    /// 称号評価
    private func evaluateAchievements(_ result: TimeAttackResult) {
        let badges = AchievementBadge.evaluateAchievements(
            for: result,
            previousBest: personalBest,
            allResults: allAttempts
        )
        
        result.badges = badges
        achievedBadges = badges
    }
    
    /// セッションリセット
    private func resetSession() {
        isActive = false
        currentTask = nil
        currentResult = nil
        isNewRecord = false
        achievedBadges = []
        retryCount = 0
    }
    
    // MARK: - Computed Properties
    
    /// 現在のパフォーマンス統計
    var currentStats: TimeAttackStats? {
        guard let task = currentTask else { return nil }
        
        return TimeAttackStats(
            task: task,
            attempts: allAttempts.count,
            personalBest: personalBest,
            lastAttempt: previousAttempt,
            averageTime: allAttempts.isEmpty ? nil : 
                allAttempts.reduce(0.0) { $0 + $1.completionTime } / Double(allAttempts.count),
            successRate: allAttempts.isEmpty ? 0.0 :
                Double(allAttempts.filter { $0.finalAccuracy >= 95.0 }.count) / Double(allAttempts.count) * 100.0
        )
    }
    
    /// 現在のパフォーマンス評価
    var currentPerformanceRating: String {
        guard isActive,
              let task = currentTask,
              let estimatedTime = estimatedCompletionTime else { return "No data" }
        
        let difficulty = task.timeAttackDifficulty
        let targetTime = difficulty.recommendedTimeLimit
        let currentAccuracy = typingTestManager.characterAccuracy
        
        if estimatedTime <= targetTime * 0.8 && currentAccuracy >= 98.0 {
            return "Excellent pace!"
        } else if estimatedTime <= targetTime && currentAccuracy >= 95.0 {
            return "Good pace"
        } else if estimatedTime <= targetTime * 1.2 && currentAccuracy >= 90.0 {
            return "Fair pace"
        } else {
            return "Needs improvement"
        }
    }
    
    /// 新記録の可能性
    var newRecordPossible: Bool {
        guard let personalBest = personalBest,
              let estimatedTime = estimatedCompletionTime else {
            return true // 初回記録
        }
        
        return estimatedTime < personalBest.completionTime && typingTestManager.characterAccuracy >= 95.0
    }
}

// MARK: - Supporting Types

/// Time Attack 統計情報
struct TimeAttackStats {
    let task: IELTSTask
    let attempts: Int
    let personalBest: TimeAttackResult?
    let lastAttempt: TimeAttackResult?
    let averageTime: TimeInterval?
    let successRate: Double
    
    var hasAttempts: Bool { attempts > 0 }
    var hasPersonalBest: Bool { personalBest != nil }
    
    var formattedPersonalBest: String {
        guard let best = personalBest else { return "No record" }
        return best.formattedTime
    }
    
    var formattedAverageTime: String {
        guard let avg = averageTime else { return "No data" }
        let minutes = Int(avg) / 60
        let seconds = avg.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    var formattedLastAttempt: String {
        guard let last = lastAttempt else { return "No attempts" }
        return last.formattedTime
    }
    
    var successRateString: String {
        return String(format: "%.1f%%", successRate)
    }
    
    /// 改善の余地があるか
    var hasRoomForImprovement: Bool {
        guard let best = personalBest else { return true }
        return best.finalAccuracy < 98.0 || best.correctionCost > 2
    }
    
    /// 推奨される次のアクション
    var recommendedAction: String {
        if !hasAttempts {
            return "Try your first attempt!"
        } else if hasRoomForImprovement {
            return "Practice for better accuracy"
        } else {
            return "Challenge a harder task"
        }
    }
}