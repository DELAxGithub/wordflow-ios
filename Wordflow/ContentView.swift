//
//  ContentView.swift
//  Wordflow - IELTS Writing Practice App
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        BasicTypingPracticeView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [IELTSTask.self, TypingResult.self], inMemory: true)
}
