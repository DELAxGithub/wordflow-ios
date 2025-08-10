//
//  Tag.swift
//  Wordflow
//
//  Created by Hiroshi Kodera on 2025-08-09.
//

import Foundation
import SwiftData

// MARK: - Tag Model

@Model
final class Tag {
    var id: UUID
    var name: String
    var color: String // Hex color code
    var createdAt: Date
    
    // Relationships (will be connected in Phase 2)
    // var documents: [Document] = []
    
    init(name: String, color: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdAt = Date()
    }
}

// MARK: - Tag Extensions

extension Tag {
    // Predefined system tags
    static let systemTags = [
        Tag(name: "Work", color: "#007AFF"),
        Tag(name: "Personal", color: "#34C759"),
        Tag(name: "Research", color: "#FF9500"),
        Tag(name: "Draft", color: "#FF3B30"),
        Tag(name: "Review", color: "#AF52DE"),
        Tag(name: "Published", color: "#00C7BE")
    ]
}