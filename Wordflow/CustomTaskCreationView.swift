//
//  CustomTaskCreationView.swift
//  Wordflow - Typing Practice App
//

import SwiftUI

struct CustomTaskCreationView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onTaskCreated: (IELTSTask) -> Void
    let taskRepository: IELTSTaskRepository?
    
    // Form state
    @State private var taskType: TaskType = .task1
    @State private var topic: String = ""
    @State private var customText: String = ""
    @State private var targetBandScore: Double = 7.0
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    
    // Validation computed properties
    private var wordCount: Int {
        let words = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private var characterCount: Int {
        return customText.count
    }
    
    private var isFormValid: Bool {
        return !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               characterCount >= 50 && // Minimum 50 characters
               characterCount <= 2000   // Maximum 2000 characters
    }
    
    private var recommendedWordCount: Int {
        switch taskType {
        case .task1: return 150
        case .task2: return 250
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Custom Task")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    createCustomTask()
                }
                .disabled(!isFormValid || isCreating)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Task Type Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Type")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Task Type", selection: $taskType) {
                            ForEach(TaskType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.systemImage)
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("Recommended: \(recommendedWordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                
                    // Topic Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter topic or title", text: $topic)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Give your practice text a descriptive title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                
                    // Custom Text Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Practice Text")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(characterCount) chars, \(wordCount) words")
                                .font(.caption)
                                .foregroundColor(textLengthColor)
                        }
                        
                        TextEditor(text: $customText)
                            .font(.body)
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        if customText.isEmpty {
                            Text("Enter the text you want to practice typing...")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                
                    // Validation Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Validation")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ValidationRow(
                                text: "Topic provided",
                                isValid: !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            
                            ValidationRow(
                                text: "Text provided",
                                isValid: !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            
                            ValidationRow(
                                text: "Minimum 50 characters",
                                isValid: characterCount >= 50
                            )
                            
                            ValidationRow(
                                text: "Maximum 2000 characters",
                                isValid: characterCount <= 2000
                            )
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                
                    // Band Score Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Band Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("Band Score:")
                            
                            Spacer()
                            
                            Picker("Band Score", selection: $targetBandScore) {
                                ForEach([5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0], id: \.self) { score in
                                    Text(String(format: "%.1f", score)).tag(score)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                        }
                        
                        Text("Set your target proficiency level for reference")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var textLengthColor: Color {
        if characterCount < 50 {
            return .red
        } else if characterCount > 2000 {
            return .red
        } else if characterCount > 1500 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private func createCustomTask() {
        guard let repository = taskRepository else {
            alertMessage = "Repository not available"
            showingAlert = true
            return
        }
        
        guard isFormValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
        isCreating = true
        
        // Create the custom task
        if let newTask = repository.createTask(
            taskType: taskType,
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            modelAnswer: customText.trimmingCharacters(in: .whitespacesAndNewlines),
            targetBandScore: targetBandScore
        ) {
            onTaskCreated(newTask)
            dismiss()
        } else {
            isCreating = false
            alertMessage = "Failed to create custom task. Please try again."
            showingAlert = true
        }
    }
}

// MARK: - Supporting Views

struct ValidationRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .primary : .secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CustomTaskCreationView(
        onTaskCreated: { task in
            print("Task created: \(task.topic)")
        },
        taskRepository: nil
    )
}