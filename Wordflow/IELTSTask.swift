//
//  IELTSTask.swift
//  Wordflow
//
//  Typing Practice App - Core Data Models
//

import Foundation
import SwiftData

// MARK: - IELTSTask Model (MVP Version - Simplified)

@Model
final class IELTSTask {
    @Attribute(.unique) var id: UUID
    var taskType: TaskType
    var topic: String
    var modelAnswer: String
    var targetBandScore: Double
    var wordCount: Int
    var createdDate: Date
    var lastUsedDate: Date?
    
    @Relationship(deleteRule: .cascade)
    var typingResults: [TypingResult] = []
    
    @Relationship(deleteRule: .cascade)
    var timeAttackResults: [TimeAttackResult] = []
    
    init(taskType: TaskType, topic: String, modelAnswer: String, targetBandScore: Double) {
        self.id = UUID()
        self.taskType = taskType
        self.topic = topic
        self.modelAnswer = modelAnswer
        self.targetBandScore = targetBandScore
        self.wordCount = modelAnswer.count // Simplified: character count
        self.createdDate = Date()
        self.lastUsedDate = nil
    }
    
    // Mark task as recently used
    func markAsUsed() {
        self.lastUsedDate = Date()
    }
    
    // Get target word count based on task type
    var targetWordCount: Int {
        switch taskType {
        case .task1:
            return 150
        case .task2:
            return 250
        }
    }
    
    // Calculate estimated reading time (words per minute)
    var estimatedReadingTime: Int {
        let wordCount = modelAnswer.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        return max(1, wordCount / 200) // 200 words per minute
    }
}

// MARK: - TaskType Enumeration

enum TaskType: String, CaseIterable, Codable {
    case task1 = "task1"  // 150 words
    case task2 = "task2"  // 250 words
    
    var displayName: String {
        switch self {
        case .task1: return "Task 1 (150 words)"
        case .task2: return "Task 2 (250 words)"
        }
    }
    
    var shortName: String {
        switch self {
        case .task1: return "Task 1"
        case .task2: return "Task 2"
        }
    }
    
    var targetWords: Int {
        switch self {
        case .task1: return 150
        case .task2: return 250
        }
    }
    
    var systemImage: String {
        switch self {
        case .task1: return "chart.bar.doc.horizontal"
        case .task2: return "doc.text"
        }
    }
}