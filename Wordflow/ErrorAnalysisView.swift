//
//  ErrorAnalysisView.swift
//  Wordflow - Error Analysis System
//
//  Created by Claude Code on 2025/08/12.
//

import SwiftUI
import Foundation

struct ErrorAnalysisView: View {
    let analysis: DetailedErrorAnalysis
    @State private var selectedErrorType: ErrorType?
    @State private var showingDetailedErrors = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            if analysis.hasErrors {
                // Error Overview
                errorOverviewSection
                
                // Error Breakdown Chart
                errorBreakdownSection
                
                // Suggestions
                suggestionsSection
                
                // Detailed Errors (expandable)
                detailedErrorsSection
            } else {
                // Perfect typing message
                perfectTypingView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Error Analysis")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                StatPill(
                    label: "Errors", 
                    value: "\(analysis.totalErrors)",
                    color: analysis.totalErrors == 0 ? .green : .red
                )
                
                StatPill(
                    label: "Accuracy", 
                    value: "\(String(format: "%.1f", analysis.accuracy))%",
                    color: accuracyColor
                )
            }
        }
    }
    
    // MARK: - Error Overview Section
    
    private var errorOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                OverviewCard(
                    title: "Total Errors", 
                    value: "\(analysis.totalErrors)",
                    subtitle: "characters",
                    color: .red,
                    icon: "exclamationmark.triangle"
                )
                
                OverviewCard(
                    title: "Error Rate", 
                    value: "\(String(format: "%.1f", analysis.errorRate))%",
                    subtitle: "of input",
                    color: errorRateColor,
                    icon: "percent"
                )
                
                OverviewCard(
                    title: "Completion", 
                    value: "\(String(format: "%.0f", analysis.completionRate))%",
                    subtitle: "of text",
                    color: completionColor,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
    }
    
    // MARK: - Error Breakdown Section
    
    private var errorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Error Types")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(analysis.errorBreakdown.keys.count) different types")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(analysis.errorBreakdown.keys.sorted { 
                    analysis.errorBreakdown[$0] ?? 0 > analysis.errorBreakdown[$1] ?? 0 
                }), id: \.self) { errorType in
                    ErrorTypeCard(
                        errorType: errorType,
                        count: analysis.errorBreakdown[errorType] ?? 0,
                        isSelected: selectedErrorType == errorType
                    )
                    .onTapGesture {
                        selectedErrorType = selectedErrorType == errorType ? nil : errorType
                    }
                }
            }
        }
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Improvement Suggestions")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            if analysis.suggestions.isEmpty {
                Text("Keep practicing to maintain your accuracy!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(analysis.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Detailed Errors Section
    
    private var detailedErrorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showingDetailedErrors.toggle()
            }) {
                HStack {
                    Image(systemName: "list.bullet.below.rectangle")
                        .foregroundColor(.blue)
                    Text("Detailed Errors")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(analysis.characterErrors.count) errors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showingDetailedErrors ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showingDetailedErrors)
                }
            }
            .buttonStyle(.plain)
            
            if showingDetailedErrors {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(analysis.characterErrors.enumerated()), id: \.offset) { index, error in
                            DetailedErrorRow(error: error, index: index + 1)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Perfect Typing View
    
    private var perfectTypingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Perfect Typing!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            
            Text("No errors detected in your input")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var accuracyColor: Color {
        if analysis.accuracy >= 98 { return .green }
        else if analysis.accuracy >= 95 { return .blue }
        else if analysis.accuracy >= 90 { return .orange }
        else { return .red }
    }
    
    private var errorRateColor: Color {
        if analysis.errorRate <= 2 { return .green }
        else if analysis.errorRate <= 5 { return .blue }
        else if analysis.errorRate <= 10 { return .orange }
        else { return .red }
    }
    
    private var completionColor: Color {
        if analysis.completionRate >= 100 { return .green }
        else if analysis.completionRate >= 90 { return .blue }
        else if analysis.completionRate >= 75 { return .orange }
        else { return .red }
    }
}

// MARK: - Supporting Views

struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorTypeCard: View {
    let errorType: ErrorType
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: errorType.iconName)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.body)
                
                Spacer()
                
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(errorType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(errorType.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(isSelected ? Color.blue : Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct DetailedErrorRow: View {
    let error: CharacterError
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            Text("Position \(error.position + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: error.errorType.iconName)
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(error.errorType.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 120, alignment: .leading)
            
            Text(error.displayText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    let sampleAnalysis = DetailedErrorAnalysis(
        totalErrors: 5,
        accuracy: 92.3,
        completionRate: 87.5,
        errorBreakdown: [
            .substitutionError: 2,
            .adjacentKeyError: 2,
            .caseError: 1
        ],
        characterErrors: [
            CharacterError(position: 5, inputChar: "q", targetChar: "w", errorType: .adjacentKeyError),
            CharacterError(position: 12, inputChar: "t", targetChar: "T", errorType: .caseError),
            CharacterError(position: 18, inputChar: "x", targetChar: "c", errorType: .substitutionError)
        ],
        mostCommonErrors: [.substitutionError, .adjacentKeyError, .caseError],
        suggestions: [
            "Focus on finger placement to avoid adjacent key mistakes",
            "Practice maintaining proper capitalization"
        ]
    )
    
    ErrorAnalysisView(analysis: sampleAnalysis)
        .frame(width: 600, height: 500)
}