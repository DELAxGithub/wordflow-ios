//
//  ComparisonMetricView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI

struct ComparisonMetricView: View {
    let title: String
    let current: Double
    let previous: Double
    let icon: String
    var isPercentage: Bool = false
    var isBest: Bool = false
    
    private var improvementValue: Double {
        current - previous
    }
    
    private var improvementPercentage: Double {
        guard previous > 0 else { return 0 }
        return (current - previous) / previous * 100
    }
    
    private var isImprovement: Bool {
        current > previous
    }
    
    private var improvementColor: Color {
        if abs(improvementValue) < 0.1 { return .gray } // Negligible change
        return isImprovement ? .green : .red
    }
    
    private var improvementIcon: String {
        if abs(improvementValue) < 0.1 { return "equal.circle.fill" }
        return isImprovement ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // アイコンとタイトル
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(isBest ? .orange : .blue)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 現在の値
            Text(formatValue(current))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
            
            // 比較表示
            HStack(spacing: 2) {
                Image(systemName: improvementIcon)
                    .font(.system(size: 8))
                    .foregroundColor(improvementColor)
                
                Text(formatImprovement())
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(improvementColor)
            }
        }
        .frame(minWidth: 50)
    }
    
    private func formatValue(_ value: Double) -> String {
        if isPercentage {
            return String(format: "%.0f%%", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    private func formatImprovement() -> String {
        if abs(improvementValue) < 0.1 {
            return "="
        }
        
        let sign = isImprovement ? "+" : ""
        if isPercentage {
            return "\(sign)\(String(format: "%.0f%%", improvementValue))"
        } else {
            return "\(sign)\(String(format: "%.0f", improvementValue))"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Improvement case
            ComparisonMetricView(
                title: "WPM",
                current: 45.0,
                previous: 40.0,
                icon: "speedometer"
            )
            
            // Decline case
            ComparisonMetricView(
                title: "Accuracy",
                current: 92.0,
                previous: 95.0,
                icon: "target",
                isPercentage: true
            )
            
            // Best record case
            ComparisonMetricView(
                title: "WPM",
                current: 48.0,
                previous: 50.0,
                icon: "crown.fill",
                isBest: true
            )
        }
    }
    .padding()
}