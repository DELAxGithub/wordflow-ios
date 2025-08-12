//
//  TimeAttackCompletionView.swift
//  Wordflow - Time Attack Completion Results
//
//  Created by Claude Code on 2025/08/11.
//

import SwiftUI

struct TimeAttackCompletionView: View {
    // MARK: - Properties
    
    let result: TimeAttackResult
    let isNewRecord: Bool
    let achievedBadges: [AchievementBadge]
    
    let onRetry: () -> Void
    let onNewTask: () -> Void
    let onClose: () -> Void
    
    // MARK: - Animation State
    
    @State private var isAnimating = false
    @State private var showBadges = false
    @State private var showStats = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Main Modal
            VStack(spacing: 24) {
                // Header with celebration
                headerSection
                
                // Results Display
                resultsSection
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 20)
                
                // Achievement Badges
                if !achievedBadges.isEmpty {
                    badgesSection
                        .opacity(showBadges ? 1 : 0)
                        .scaleEffect(showBadges ? 1 : 0.8)
                }
                
                // Action Buttons
                actionButtons
                    .opacity(showStats ? 1 : 0)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(radius: 20)
            )
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            .frame(minWidth: 650, maxWidth: 750)
            
            // Celebration Effects
            if isNewRecord && isAnimating {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isNewRecord ? .green : .orange)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimating)
                
                Image(systemName: isNewRecord ? "trophy.fill" : "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1 : 0.3)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: isAnimating)
            }
            
            // Title
            VStack(spacing: 8) {
                Text(isNewRecord ? "🎉 NEW RECORD! 🎉" : "⚡ TIME ATTACK COMPLETE! ⚡")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isNewRecord ? .green : .orange)
                
                Text(result.task?.topic ?? "Unknown Task")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : -10)
            .animation(.easeOut(duration: 0.6).delay(0.7), value: isAnimating)
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 24) {
            Text("Your Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Main stats grid (2x3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), spacing: 20) {
                ResultCard(
                    icon: "timer",
                    title: "Completion Time",
                    value: result.formattedTime,
                    subtitle: isNewRecord ? "New Personal Best!" : improvementText,
                    color: isNewRecord ? .green : .orange,
                    isHighlighted: isNewRecord
                )
                
                ResultCard(
                    icon: "target",
                    title: "Accuracy",
                    value: String(format: "%.1f%%", result.finalAccuracy),
                    subtitle: result.isFormulaValid ? accuracyFeedback : "⚠️ Check formula",
                    color: result.isFormulaValid ? accuracyColor : .red,
                    isHighlighted: result.isFormulaValid && result.finalAccuracy >= 98.0
                )
                
                ResultCard(
                    icon: "speedometer",
                    title: "Gross WPM",
                    value: String(format: "%.1f", result.grossWPM),
                    subtitle: "Words per minute (CPM/5)",
                    color: .blue,
                    isHighlighted: result.grossWPM >= 60.0
                )
                
                ResultCard(
                    icon: "gauge",
                    title: "Net WPM", 
                    value: result.isFormulaValid ? String(format: "%.1f", result.netWPM) : "FAIL",
                    subtitle: result.isFormulaValid ? "Gross × Accuracy%" : "⚠️ Formula error",
                    color: result.isFormulaValid ? netWPMColor : .red,
                    isHighlighted: result.isFormulaValid && result.netWPM >= 50.0
                )
                
                ResultCard(
                    icon: "gearshape.fill",
                    title: "Corrections",
                    value: "\(result.correctionCost)",
                    subtitle: correctionFeedback,
                    color: correctionColor,
                    isHighlighted: result.correctionCost == 0
                )
                
                ResultCard(
                    icon: "star.fill",
                    title: "Grade",
                    value: result.performanceGrade,
                    subtitle: gradeDescription,
                    color: gradeColor,
                    isHighlighted: result.performanceGrade.hasPrefix("A")
                )
            }
            
            // Advanced metrics section
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced Metrics")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 16) {
                    MetricCard(
                        title: "KSPC",
                        value: String(format: "%.2f", result.kspc),
                        subtitle: "Keystrokes per char",
                        color: kspcColor
                    )
                    
                    MetricCard(
                        title: "Backspace Rate",
                        value: String(format: "%.1f%%", result.backspaceRate),
                        subtitle: "Correction frequency",
                        color: backspaceRateColor
                    )
                    
                    MetricCard(
                        title: "Total Keystrokes",
                        value: "\(result.totalKeystrokes)",
                        subtitle: "Keys pressed",
                        color: .gray
                    )
                    
                    MetricCard(
                        title: "Quality Score",
                        value: String(format: "%.1f", result.qualityScore),
                        subtitle: qualityDescription,
                        color: qualityScoreColor
                    )
                }
            }
            
            // Comparison with previous attempts
            if let improvementTime = result.improvementTime {
                comparisonSection(improvementTime)
            }
        }
        .animation(.easeOut(duration: 0.5).delay(1.0), value: showStats)
    }
    
    private func comparisonSection(_ improvementTime: TimeInterval) -> some View {
        HStack {
            Image(systemName: improvementTime > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(improvementTime > 0 ? .green : .red)
            
            Text(improvementTime > 0 ? "Improved by \(String(format: "%.2f", improvementTime))s" : "Slower by \(String(format: "%.2f", abs(improvementTime)))s")
                .font(.subheadline)
                .foregroundColor(improvementTime > 0 ? .green : .red)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(spacing: 16) {
            Text("Achievements Unlocked!")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(achievedBadges.count, 3)), spacing: 12) {
                ForEach(achievedBadges, id: \.rawValue) { badge in
                    BadgeView(badge: badge)
                        .scaleEffect(showBadges ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(achievedBadges.firstIndex(of: badge) ?? 0) * 0.1), value: showBadges)
                }
            }
        }
        .animation(.easeOut(duration: 0.5).delay(1.5), value: showBadges)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Retry Same Task", systemImage: "arrow.clockwise") {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("Try Different Task", systemImage: "doc.text") {
                onNewTask()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("Continue", systemImage: "checkmark") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .animation(.easeOut(duration: 0.3).delay(2.0), value: showStats)
    }
    
    // MARK: - Animation Methods
    
    private func startAnimationSequence() {
        withAnimation(.easeOut(duration: 0.3)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showStats = true
            }
        }
        
        if !achievedBadges.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showBadges = true
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var improvementText: String {
        guard let improvementTime = result.improvementTime else {
            return "First attempt"
        }
        
        if improvementTime > 0 {
            return "↗️ +\(String(format: "%.2f", improvementTime))s"
        } else {
            return "↘️ \(String(format: "%.2f", improvementTime))s"
        }
    }
    
    private var accuracyFeedback: String {
        let accuracy = result.finalAccuracy
        if accuracy == 100.0 { return "Perfect!" }
        else if accuracy >= 98.0 { return "Excellent" }
        else if accuracy >= 95.0 { return "Very Good" }
        else if accuracy >= 90.0 { return "Good" }
        else { return "Needs Practice" }
    }
    
    private var correctionFeedback: String {
        let corrections = result.correctionCost
        if corrections == 0 { return "Flawless!" }
        else if corrections <= 2 { return "Excellent" }
        else if corrections <= 5 { return "Good" }
        else { return "Practice More" }
    }
    
    private var gradeDescription: String {
        switch result.performanceGrade {
        case "A+": return "Outstanding!"
        case "A": return "Excellent!"
        case "B+": return "Very Good"
        case "B": return "Good"
        case "C+": return "Fair"
        case "C": return "Improving"
        default: return "Keep Practicing"
        }
    }
    
    private var accuracyColor: Color {
        let accuracy = result.finalAccuracy
        if accuracy >= 98 { return .green }
        else if accuracy >= 95 { return .blue }
        else if accuracy >= 90 { return .orange }
        else { return .red }
    }
    
    private var correctionColor: Color {
        let corrections = result.correctionCost
        if corrections == 0 { return .green }
        else if corrections <= 2 { return .blue }
        else if corrections <= 5 { return .orange }
        else { return .red }
    }
    
    private var gradeColor: Color {
        switch result.performanceGrade {
        case "A+", "A": return .green
        case "B+", "B": return .blue
        case "C+", "C": return .orange
        default: return .red
        }
    }
    
    private var netWPMColor: Color {
        let netWPM = result.netWPM
        if netWPM >= 50 { return .green }
        else if netWPM >= 35 { return .blue }
        else if netWPM >= 20 { return .orange }
        else { return .red }
    }
    
    private var qualityScoreColor: Color {
        let quality = result.qualityScore
        if quality >= 45 { return .green }
        else if quality >= 30 { return .blue }
        else if quality >= 15 { return .orange }
        else { return .red }
    }
    
    private var qualityDescription: String {
        let quality = result.qualityScore
        if quality >= 45 { return "Excellent" }
        else if quality >= 30 { return "Good" }
        else if quality >= 15 { return "Fair" }
        else { return "Needs Practice" }
    }
    
    private var kspcColor: Color {
        let kspc = result.kspc
        if kspc <= 1.05 { return .green }      // Excellent efficiency
        else if kspc <= 1.15 { return .blue } // Good efficiency  
        else if kspc <= 1.30 { return .orange } // Fair efficiency
        else { return .red }                   // Poor efficiency
    }
    
    private var backspaceRateColor: Color {
        let rate = result.backspaceRate
        if rate <= 2.0 { return .green }       // Very low error rate
        else if rate <= 5.0 { return .blue }  // Low error rate
        else if rate <= 10.0 { return .orange } // Moderate error rate
        else { return .red }                   // High error rate
    }
}

// MARK: - Metric Card View (Compact)

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Result Card View

struct ResultCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(isHighlighted ? color : .primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isHighlighted ? color : .secondary)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? color.opacity(0.1) : Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted ? color.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let badge: AchievementBadge
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Circle()
                    .stroke(badgeColor, lineWidth: 2)
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.iconName)
                    .font(.title2)
                    .foregroundColor(badgeColor)
            }
            
            VStack(spacing: 2) {
                Text(badge.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(badge.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 120)
    }
    
    private var badgeColor: Color {
        switch badge.color {
        case "orange": return .orange
        case "gold": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                ConfettiPiece()
                    .opacity(isAnimating ? 0 : 1)
                    .scaleEffect(isAnimating ? 0.1 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 2...4))
                        .delay(Double.random(in: 0...0.5)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let color = [Color.red, .blue, .green, .yellow, .purple, .orange].randomElement()!
    let size = CGFloat.random(in: 4...8)
    let x = CGFloat.random(in: 0...(NSScreen.main?.frame.width ?? 800))
    let y = CGFloat.random(in: 0...100)
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    let sampleTask = IELTSTask(
        taskType: .task2,
        topic: "Technology and Education",
        modelAnswer: "Sample model answer text for preview purposes.",
        targetBandScore: 7.5
    )
    
    let sampleResult = TimeAttackResult(
        task: sampleTask,
        completionTime: 78.3,
        accuracy: 98.5,
        correctionCost: 2,
        userInput: "Sample user input"
    )
    
    return TimeAttackCompletionView(
        result: sampleResult,
        isNewRecord: true,
        achievedBadges: [.recordBreaker, .sharpshooter, .efficient],
        onRetry: {},
        onNewTask: {},
        onClose: {}
    )
}