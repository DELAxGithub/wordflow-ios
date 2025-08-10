//
//  Document.swift
//  Wordflow
//
//  Created by Hiroshi Kodera on 2025-08-09.
//

import Foundation
import SwiftData

// MARK: - Document Model

@Model
final class Document {
    // Basic Properties
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    // Analytics Properties
    var wordCount: Int
    var characterCount: Int
    var estimatedReadingTime: Int
    
    // Metadata
    var documentType: DocumentType
    var status: DocumentStatus
    var priority: Priority
    
    // Relationships (Phase 2 - coming soon)
    // var project: Project?
    // var tags: [Tag] = []
    // var sessions: [WritingSession] = []
    
    init(title: String, content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.documentType = .markdown
        self.status = .draft
        self.priority = .medium
        
        // Initialize analytics
        self.wordCount = 0
        self.characterCount = 0
        self.estimatedReadingTime = 0
        
        // Update counts
        updateCounts()
    }
    
    func updateCounts() {
        self.characterCount = content.count
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        self.estimatedReadingTime = max(1, wordCount / 200) // 200 words per minute
        self.updatedAt = Date()
    }
    
    // Export functionality
    func exportAsMarkdown() -> String {
        var markdown = "# \(title)\n\n"
        markdown += content
        markdown += "\n\n---\n"
        markdown += "Created: \(createdAt.formatted())\n"
        markdown += "Updated: \(updatedAt.formatted())\n"
        markdown += "Words: \(wordCount) | Reading time: \(estimatedReadingTime) min\n"
        return markdown
    }
}

// MARK: - Enumerations

enum DocumentType: String, CaseIterable, Codable {
    case markdown = "markdown"
    case plainText = "plainText"
    case richText = "richText"
    
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        case .richText: return "Rich Text"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .richText: return "rtf"
        }
    }
}

enum DocumentStatus: String, CaseIterable, Codable {
    case draft = "draft"
    case inReview = "inReview"
    case completed = "completed"
    case published = "published"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inReview: return "In Review"
        case .completed: return "Completed"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }
    
    var systemImage: String {
        switch self {
        case .draft: return "pencil"
        case .inReview: return "eye"
        case .completed: return "checkmark"
        case .published: return "paperplane"
        case .archived: return "archivebox"
        }
    }
}

enum Priority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#007AFF"
        case .high: return "#FF9500"
        case .urgent: return "#FF3B30"
        }
    }
}