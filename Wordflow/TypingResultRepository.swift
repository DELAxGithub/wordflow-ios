//
//  TypingResultRepository.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import SwiftData

@MainActor
final class TypingResultRepository: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAllResults() -> [TypingResult] {
        let descriptor = FetchDescriptor<TypingResult>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch typing results: \(error)")
            return []
        }
    }
    
    func fetchResultsForTask(_ task: IELTSTask) -> [TypingResult] {
        let taskId = task.id
        let descriptor = FetchDescriptor<TypingResult>(
            predicate: #Predicate { $0.task?.id == taskId },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch results for task: \(error)")
            return []
        }
    }
    
    func fetchRecentResults(limit: Int = 10) -> [TypingResult] {
        var descriptor = FetchDescriptor<TypingResult>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch recent results: \(error)")
            return []
        }
    }
    
    func saveResult(_ result: TypingResult) {
        do {
            modelContext.insert(result)
            try modelContext.save()
        } catch {
            print("Failed to save typing result: \(error)")
        }
    }
    
    func deleteResult(_ result: TypingResult) {
        do {
            modelContext.delete(result)
            try modelContext.save()
        } catch {
            print("Failed to delete result: \(error)")
        }
    }
    
    // Export results to CSV
    func exportToCSV() -> String {
        let results = fetchAllResults()
        
        var csv = "Date,Task Type,WPM,Accuracy,Completion,Errors,Duration\n"
        
        for result in results {
            csv += result.toCsvRow() + "\n"
        }
        
        return csv
    }
}