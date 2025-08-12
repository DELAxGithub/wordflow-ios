//
//  TimeAttackResult.swift
//  Wordflow - Time Attack Mode
//
//  Created by Claude Code on 2025/08/11.
//

import Foundation
import SwiftData

@Model
final class TimeAttackResult {
    // MARK: - Primary Properties
    @Attribute(.unique) var id: UUID
    var completionTime: TimeInterval        // 完了時間（秒、小数点以下2桁）
    var finalAccuracy: Double              // 最終正確性（0.0-100.0%）
    var correctionCost: Int                // Delete/Backspace使用回数
    var achievedAt: Date                   // 達成日時
    var userInput: String                  // 入力されたテキスト（検証・復習用）
    
    // MARK: - Achievement Properties
    var isPersonalBest: Bool               // 自己ベスト記録フラグ
    var improvementTime: TimeInterval?     // 前回からの改善時間（秒）
    var achievementBadges: [String]        // 獲得した称号リスト
    
    // MARK: - Performance Analysis
    var averageWPM: Double                 // 平均WPM（参考値）
    var peakWPM: Double                    // 最高WPM（参考値）
    var consistencyScore: Double           // 一貫性スコア（0.0-1.0）
    
    // MARK: - Enhanced Metrics (Issue #31)
    var grossWPM: Double                   // (総打鍵文字数/5) ÷ 分
    var netWPM: Double                     // grossWPM − (未修正エラー数 ÷ 分)
    var kspc: Double                       // 総打鍵キー数 ÷ 原文文字数
    var backspaceRate: Double              // Backspace回数 ÷ 総打鍵キー数
    var totalKeystrokes: Int               // 総打鍵キー数
    var backspaceCount: Int                // Backspace使用回数
    var qualityScore: Double               // Net WPM × Accuracy ÷ 100
    
    // MARK: - Session Metadata
    var sessionDuration: TimeInterval      // セッション全体時間（休憩含む）
    var startedAt: Date                    // セッション開始時刻
    var retryCount: Int                   // 同一タスクでの再試行回数
    var deviceInfo: String                // デバイス情報（Mac model等）
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var task: IELTSTask?                   // 関連するIELTSTask
    
    // MARK: - Initializers
    init(task: IELTSTask, completionTime: TimeInterval, accuracy: Double, 
         correctionCost: Int, userInput: String, scoringResult: ScoringResult? = nil) {
        self.id = UUID()
        self.task = task
        self.completionTime = completionTime
        self.finalAccuracy = accuracy
        self.correctionCost = correctionCost
        self.userInput = userInput
        self.achievedAt = Date()
        self.startedAt = Date() - completionTime  // 開始時刻を逆算
        
        // デフォルト値の設定
        self.isPersonalBest = false
        self.improvementTime = nil
        self.achievementBadges = []
        self.averageWPM = 0.0
        self.peakWPM = 0.0
        self.consistencyScore = 0.0
        self.sessionDuration = completionTime
        self.retryCount = 0
        self.deviceInfo = TimeAttackResult.generateDeviceInfo()
        
        // Enhanced metrics from scoring result
        if let scoring = scoringResult {
            self.grossWPM = scoring.grossWPM
            self.netWPM = scoring.netWPM
            self.kspc = scoring.kspc
            self.backspaceRate = scoring.backspaceRate
            self.totalKeystrokes = scoring.totalKeystrokes
            self.backspaceCount = scoring.backspaceCount
            self.qualityScore = scoring.qualityScore
        } else {
            // Default values
            self.grossWPM = 0.0
            self.netWPM = 0.0
            self.kspc = 0.0
            self.backspaceRate = 0.0
            self.totalKeystrokes = 0
            self.backspaceCount = 0
            self.qualityScore = 0.0
        }
    }
    
    // MARK: - Computed Properties
    
    /// 分:秒.ミリ秒 形式の時間文字列
    var formattedTime: String {
        let minutes = Int(completionTime) / 60
        let seconds = completionTime.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    
    /// パフォーマンスグレード (A+, A, B+, B, C+, C, D)
    var performanceGrade: String {
        let timeScore = calculateTimeScore()
        let accuracyScore = finalAccuracy / 100.0
        let correctionScore = max(0.0, 1.0 - Double(correctionCost) / 10.0)
        
        let totalScore = (timeScore * 0.5) + (accuracyScore * 0.3) + (correctionScore * 0.2)
        
        switch totalScore {
        case 0.95...: return "A+"
        case 0.90..<0.95: return "A"
        case 0.85..<0.90: return "B+"
        case 0.80..<0.85: return "B"
        case 0.75..<0.80: return "C+"
        case 0.70..<0.75: return "C"
        default: return "D"
        }
    }
    
    /// 称号バッジリスト（デシリアライズ）
    var badges: [AchievementBadge] {
        get {
            return achievementBadges.compactMap { AchievementBadge(rawValue: $0) }
        }
        set {
            achievementBadges = newValue.map { $0.rawValue }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 時間スコア計算（タスクの難易度に基づく相対評価）
    private func calculateTimeScore() -> Double {
        guard let task = task else { return 0.0 }
        
        // タスクタイプ別の基準時間
        let baselineTime: TimeInterval = switch task.taskType {
        case .task1: 90.0   // Task 1: 150語 → 90秒基準
        case .task2: 150.0  // Task 2: 250語 → 150秒基準
        }
        
        // スコア = min(1.0, baselineTime / actualTime)
        return min(1.0, baselineTime / completionTime)
    }
    
    /// デバイス情報生成
    private static func generateDeviceInfo() -> String {
        #if os(macOS)
        let modelName = ProcessInfo.processInfo.machineHardwareName ?? "Unknown Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(modelName) - \(osVersion)"
        #else
        return "Unknown Device"
        #endif
    }
    
    // MARK: - Export Methods
    
    /// CSV行形式でのエクスポート
    func toCsvRow() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let components = [
            dateFormatter.string(from: achievedAt),
            task?.taskType.shortName ?? "Unknown",
            task?.topic ?? "Unknown",
            String(format: "%.2f", completionTime),
            String(format: "%.1f", finalAccuracy),
            String(correctionCost),
            performanceGrade,
            isPersonalBest ? "YES" : "NO",
            String(format: "%.1f", averageWPM),
            String(format: "%.1f", grossWPM),
            String(format: "%.1f", netWPM),
            String(format: "%.2f", kspc),
            String(format: "%.1f", backspaceRate),
            String(totalKeystrokes),
            String(backspaceCount),
            String(format: "%.1f", qualityScore),
            badges.map { $0.displayName }.joined(separator: ";"),
            String(retryCount)
        ]
        
        return components.map { "\"\($0)\"" }.joined(separator: ",")
    }
    
    /// CSV ヘッダー（クラスメソッド）
    static func csvHeader() -> String {
        return [
            "date", "task_type", "topic", "completion_time", "accuracy", 
            "corrections", "grade", "personal_best", "avg_wpm", "gross_wpm", "net_wpm",
            "kspc", "backspace_rate", "total_keystrokes", "backspace_count", 
            "quality_score", "badges", "retry_count"
        ].joined(separator: ",")
    }
    
    // MARK: - Data Validation
    
    /// データ整合性検証
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // 基本データ検証
        if completionTime <= 0 {
            errors.append(.invalidCompletionTime)
        }
        
        if finalAccuracy < 0 || finalAccuracy > 100 {
            errors.append(.invalidAccuracy)
        }
        
        if correctionCost < 0 {
            errors.append(.invalidCorrectionCost)
        }
        
        if userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyUserInput)
        }
        
        // タスク関連検証
        if let task = task {
            if userInput.count > task.modelAnswer.count * 2 {
                errors.append(.excessiveInputLength)
            }
        }
        
        // パフォーマンス指標検証
        if averageWPM < 0 || averageWPM > 300 {
            errors.append(.unrealisticWPM)
        }
        
        return errors
    }
    
    /// 自動修正処理
    func autoCorrect() {
        // 範囲外の値を修正
        finalAccuracy = max(0.0, min(100.0, finalAccuracy))
        correctionCost = max(0, correctionCost)
        averageWPM = max(0.0, min(300.0, averageWPM))
        peakWPM = max(0.0, min(500.0, peakWPM))
        consistencyScore = max(0.0, min(1.0, consistencyScore))
    }
}

// MARK: - Supporting Types

/// データ検証エラー型
enum ValidationError: LocalizedError {
    case invalidCompletionTime
    case invalidAccuracy
    case invalidCorrectionCost
    case emptyUserInput
    case excessiveInputLength
    case unrealisticWPM
    
    var errorDescription: String? {
        switch self {
        case .invalidCompletionTime:
            return "Completion time must be positive"
        case .invalidAccuracy:
            return "Accuracy must be between 0% and 100%"
        case .invalidCorrectionCost:
            return "Correction cost cannot be negative"
        case .emptyUserInput:
            return "User input cannot be empty"
        case .excessiveInputLength:
            return "Input length is unreasonably long"
        case .unrealisticWPM:
            return "WPM value is outside realistic range"
        }
    }
}

// MARK: - ProcessInfo Extension (macOS)
#if os(macOS)
extension ProcessInfo {
    var machineHardwareName: String? {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        
        return String(cString: machine)
    }
}
#endif