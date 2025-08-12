//
//  ContentView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - State
    
    @State private var practiceMode: PracticeMode = .normal
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Mode Selection
            headerView
            
            Divider()
            
            // Main Content Based on Mode
            switch practiceMode {
            case .normal:
                BasicTypingPracticeView()
            case .timeAttack:
                TimeAttackView()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // App Title
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("タイピングプロジェクト")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Mode Selection
            Picker("練習モード", selection: $practiceMode) {
                ForEach(PracticeMode.allCases, id: \.self) { mode in
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .animation(.easeInOut(duration: 0.3), value: practiceMode)
        }
        .padding()
        .background(practiceMode == .timeAttack ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
        .border(practiceMode == .timeAttack ? Color.orange : Color.blue, width: 1)
    }
}

// MARK: - Practice Mode Enum

enum PracticeMode: String, CaseIterable {
    case normal = "normal"
    case timeAttack = "timeAttack"
    
    var displayName: String {
        switch self {
        case .normal: return "通常練習"
        case .timeAttack: return "タイムアタック"
        }
    }
    
    var iconName: String {
        switch self {
        case .normal: return "text.cursor"
        case .timeAttack: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "従来のタイピング練習モード"
        case .timeAttack: return "最速完了タイムを競うモード"
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [IELTSTask.self, TypingResult.self, TimeAttackResult.self], inMemory: true)
}
