//
//  TypingTestManager.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import Observation

@MainActor
@Observable
final class TypingTestManager {
    // Test state
    private(set) var isActive: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var remainingTime: TimeInterval = 120 // 2 minutes
    private(set) var elapsedTime: TimeInterval = 0
    
    // Metrics (basic only)
    private(set) var currentWPM: Double = 0
    private(set) var accuracy: Double = 100
    private(set) var completionPercentage: Double = 0
    private(set) var basicErrorCount: Int = 0
    
    // Current session
    private(set) var currentTask: IELTSTask?
    private(set) var userInput: String = ""
    private var timer: Timer?
    
    // Configuration (relaxed)
    let timeLimit: TimeInterval = 120
    let updateInterval: TimeInterval = 0.2 // 200ms (relaxed from 100ms)
    
    func startTest(with task: IELTSTask) {
        currentTask = task
        isActive = true
        isPaused = false
        remainingTime = timeLimit
        elapsedTime = 0
        userInput = ""
        resetMetrics()
        
        task.markAsUsed()
        startTimer()
    }
    
    func updateInput(_ input: String) {
        guard isActive && !isPaused else { return }
        
        userInput = input
        calculateMetrics()
    }
    
    func pauseTest() {
        guard isActive && !isPaused else { return }
        isPaused = true
        timer?.invalidate()
    }
    
    func resumeTest() {
        guard isActive && isPaused else { return }
        isPaused = false
        startTimer()
    }
    
    func endTest() -> TypingResult? {
        guard let task = currentTask else { return nil }
        
        isActive = false
        isPaused = false
        timer?.invalidate()
        
        calculateFinalMetrics()
        
        let result = TypingResult(
            task: task,
            userInput: userInput,
            duration: elapsedTime,
            wpm: currentWPM,
            accuracy: accuracy,
            completion: completionPercentage,
            errors: basicErrorCount
        )
        
        reset()
        return result
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateTimer()
            }
        }
    }
    
    private func updateTimer() {
        guard isActive && !isPaused else { return }
        
        elapsedTime += updateInterval
        remainingTime = max(0, timeLimit - elapsedTime)
        
        calculateMetrics()
        
        if remainingTime <= 0 {
            _ = endTest()
        }
    }
    
    // MVP: Simple WPM calculation
    private func calculateWPM() -> Double {
        let totalCharacters = Double(userInput.count)
        let wordsTyped = totalCharacters / 5.0
        let minutes = elapsedTime / 60.0
        return minutes > 0 ? wordsTyped / minutes : 0
    }
    
    // MVP: Basic accuracy calculation
    private func calculateAccuracy() -> Double {
        guard let task = currentTask, !userInput.isEmpty else { return 100 }
        
        let target = task.modelAnswer
        let minLength = min(userInput.count, target.count)
        var correctChars = 0
        
        for i in 0..<minLength {
            let userChar = userInput[userInput.index(userInput.startIndex, offsetBy: i)]
            let targetChar = target[target.index(target.startIndex, offsetBy: i)]
            if userChar == targetChar {
                correctChars += 1
            }
        }
        
        return userInput.count > 0 ? (Double(correctChars) / Double(userInput.count)) * 100 : 100
    }
    
    private func calculateMetrics() {
        currentWPM = calculateWPM()
        accuracy = calculateAccuracy()
        
        if let task = currentTask {
            completionPercentage = min(100, (Double(userInput.count) / Double(task.modelAnswer.count)) * 100)
            basicErrorCount = max(0, userInput.count - Int(accuracy / 100 * Double(userInput.count)))
        }
    }
    
    private func calculateFinalMetrics() {
        calculateMetrics()
    }
    
    private func resetMetrics() {
        currentWPM = 0
        accuracy = 100
        completionPercentage = 0
        basicErrorCount = 0
    }
    
    private func reset() {
        currentTask = nil
        userInput = ""
        resetMetrics()
    }
}