//
//  ContentView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - State
    
    @State private var practiceMode: PracticeMode = .normal  // 🔧 FIX: Explicitly start with normal mode
    
    // 🔧 DEBUG: Add computed property to verify state
    private var debugModeInfo: String {
        "Current mode: \(practiceMode.displayName) (\(practiceMode.rawValue))"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Mode Selection
            headerView
            
            Divider()
            
            // Main Content Based on Mode
            Group {
                // 🔧 CRITICAL FIX: Explicit switch statement for bulletproof view selection
                switch practiceMode {
                case .normal:
                    BasicTypingPracticeView()
                        .id("normal-practice-view-\(practiceMode.rawValue)")
                        .onAppear {
                            print("✅ SUCCESS: Displaying Normal Practice Mode - \(debugModeInfo)")
                            print("✅ View mapping working correctly: .normal → BasicTypingPracticeView")
                        }
                        
                case .timeAttack:
                    TimeAttackView()
                        .id("time-attack-view-\(practiceMode.rawValue)")
                        .onAppear {
                            print("✅ SUCCESS: Displaying Time Attack Mode - \(debugModeInfo)")
                            print("✅ View mapping working correctly: .timeAttack → TimeAttackView")
                        }
                }
            }
            .id("main-content-switch-\(practiceMode.rawValue)")  // Force refresh when mode changes
            .animation(nil, value: practiceMode)  // Disable animation temporarily
        }
        .onAppear {
            print("🔧 DEBUG: ContentView appeared with initial mode: \(debugModeInfo)")
            // 🚨 EMERGENCY FIX: Force initial state
            if practiceMode != .normal {
                print("🚨 CRITICAL: Forcing mode reset to normal")
                practiceMode = .normal
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
                Text("タイピングプロジェクト v1.1")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // 🔧 CLEAN FIX: Simple segmented picker without overlapping elements
            Picker("練習モード", selection: $practiceMode) {
                // 通常練習 - text cursor icon
                Text("📝 通常練習").tag(PracticeMode.normal)
                
                // タイムアタック - lightning bolt icon  
                Text("⚡ タイムアタック").tag(PracticeMode.timeAttack)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .onChange(of: practiceMode) { oldValue, newValue in
                print("🔧 DEBUG: Mode changed from \(oldValue.displayName) to \(newValue.displayName)")
                print("🔧 DEBUG: Old mode: \(oldValue.rawValue) → New mode: \(newValue.rawValue)")
                print("🔧 DEBUG: Condition check: practiceMode == .normal = \(newValue == .normal)")
            }
        }
        .padding()
        .background(practiceMode == .timeAttack ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
        .border(practiceMode == .timeAttack ? Color.orange : Color.blue, width: 1)
    }
}

// MARK: - Practice Mode Enum

enum PracticeMode: String, CaseIterable, Equatable {
    case normal = "normal"
    case timeAttack = "timeAttack"
    
    // 🔧 CRITICAL FIX: Ensure correct order for picker - normal first, timeAttack second
    static var allCases: [PracticeMode] {
        return [.normal, .timeAttack]  // Explicitly order: 通常練習 first, タイムアタック second
    }
    
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
