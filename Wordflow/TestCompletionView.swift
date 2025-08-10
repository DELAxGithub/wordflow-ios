//
//  TestCompletionView.swift
//  Wordflow - IELTS Writing Practice App
//

import SwiftUI

struct TestCompletionView: View {
    let result: TypingResult
    let timerMode: TimerMode
    let onRetry: () -> Void
    let onNewTask: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Time Up!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Test completed in \(timerMode.displayName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Results
            VStack(spacing: 16) {
                Text("Your Results")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 40) {
                    ResultMetricView(
                        title: "Words Per Minute",
                        value: String(format: "%.0f", result.finalWPM),
                        icon: "speedometer",
                        color: .green
                    )
                    
                    ResultMetricView(
                        title: "Accuracy",
                        value: String(format: "%.0f%%", result.accuracy),
                        icon: "target",
                        color: .orange
                    )
                    
                    ResultMetricView(
                        title: "Completion",
                        value: String(format: "%.0f%%", result.completionPercentage),
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Try Again", systemImage: "arrow.clockwise") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("New Task", systemImage: "doc.text") {
                    onNewTask()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Close", systemImage: "xmark") {
                    onClose()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 480)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}

struct ResultMetricView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        
        TestCompletionView(
            result: TypingResult(
                task: IELTSTask(
                    taskType: .task2,
                    topic: "Sample Topic",
                    modelAnswer: "Sample answer",
                    targetBandScore: 7.0
                ),
                userInput: "Sample input",
                duration: 120,
                wpm: 45,
                accuracy: 92,
                completion: 85,
                errors: 5
            ),
            timerMode: .twoMinutes,
            onRetry: {},
            onNewTask: {},
            onClose: {}
        )
    }
}