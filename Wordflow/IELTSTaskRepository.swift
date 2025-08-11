//
//  IELTSTaskRepository.swift
//  Wordflow - Typing Practice App
//

import Foundation
import SwiftData

@MainActor
final class IELTSTaskRepository: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAllTasks() -> [IELTSTask] {
        let descriptor = FetchDescriptor<IELTSTask>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch IELTS tasks: \(error)")
            return []
        }
    }
    
    func fetchTasksByType(_ taskType: TaskType) -> [IELTSTask] {
        let descriptor = FetchDescriptor<IELTSTask>(
            predicate: #Predicate { $0.taskType == taskType },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks by type: \(error)")
            return []
        }
    }
    
    func fetchTasksByBandScore(minScore: Double) -> [IELTSTask] {
        let descriptor = FetchDescriptor<IELTSTask>(
            predicate: #Predicate { $0.targetBandScore >= minScore },
            sortBy: [SortDescriptor(\.targetBandScore, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks by band score: \(error)")
            return []
        }
    }
    
    func createTask(taskType: TaskType, topic: String, modelAnswer: String, targetBandScore: Double) -> IELTSTask? {
        let task = IELTSTask(
            taskType: taskType,
            topic: topic,
            modelAnswer: modelAnswer,
            targetBandScore: targetBandScore
        )
        
        do {
            modelContext.insert(task)
            try modelContext.save()
            return task
        } catch {
            print("Failed to create task: \(error)")
            return nil
        }
    }
    
    func deleteTask(_ task: IELTSTask) {
        do {
            modelContext.delete(task)
            try modelContext.save()
        } catch {
            print("Failed to delete task: \(error)")
        }
    }
    
    func updateTask(_ task: IELTSTask) {
        do {
            try modelContext.save()
        } catch {
            print("Failed to update task: \(error)")
        }
    }
}