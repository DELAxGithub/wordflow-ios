//
//  Item.swift
//  Wordflow
//
//  Created by Hiroshi Kodera on 2025-08-09.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
