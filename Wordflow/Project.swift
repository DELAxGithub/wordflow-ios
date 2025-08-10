//
//  Project.swift
//  Wordflow
//
//  Created by Hiroshi Kodera on 2025-08-09.
//

import Foundation
import SwiftData

// MARK: - Project Model

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String
    var createdAt: Date
    var updatedAt: Date
    var deadline: Date?
    var targetWordCount: Int?
    var status: ProjectStatus
    
    // Relationships (will be connected in Phase 2)
    // var documents: [Document] = []
    // var tasks: [Task] = []
    // var milestones: [Milestone] = []
    
    // Computed Properties (will be implemented with relationships)
    var totalWordCount: Int {
        // documents.reduce(0) { $0 + $1.wordCount }
        return 0 // Placeholder
    }
    
    var progress: Double {
        guard let target = targetWordCount, target > 0 else { return 0 }
        return min(1.0, Double(totalWordCount) / Double(target))
    }
    
    init(name: String, description: String = "") {
        self.id = UUID()
        self.name = name
        self.projectDescription = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = .planning
        self.targetWordCount = nil
        self.deadline = nil
    }
    
    func updateProgress() {
        self.updatedAt = Date()
    }
}

// MARK: - Project Enumerations

enum ProjectStatus: String, CaseIterable, Codable {
    case planning = "planning"
    case active = "active"
    case onHold = "onHold"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}