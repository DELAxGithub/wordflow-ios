//
//  BasicTTSManager.swift
//  Wordflow - IELTS Writing Practice App
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class BasicTTSManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    // Basic state only
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    var playbackSpeed: TTSSpeed = .slow
    
    // Position tracking for rewind functionality
    private var currentText: String = ""
    private var playbackStartTime: Date?
    private var pausedTime: TimeInterval = 0
    private var totalPausedDuration: TimeInterval = 0
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MVP: Full text playback only
    func playFullText(_ text: String) {
        stop() // Stop any current playback
        
        currentText = text
        playFromPosition(text: text, startPosition: 0)
    }
    
    private func playFromPosition(text: String, startPosition: Int) {
        let textToPlay = startPosition < text.count ? String(text.dropFirst(startPosition)) : ""
        guard !textToPlay.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: textToPlay)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // US English fixed
        utterance.rate = playbackSpeed.rate
        
        playbackStartTime = Date()
        totalPausedDuration = 0
        isPlaying = true
        isPaused = false
        synthesizer.speak(utterance)
    }
    
    func pause() {
        guard isPlaying && !isPaused else { return }
        pausedTime = Date().timeIntervalSince1970
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
    }
    
    func resume() {
        guard isPlaying && isPaused else { return }
        if pausedTime > 0 {
            totalPausedDuration += Date().timeIntervalSince1970 - pausedTime
            pausedTime = 0
        }
        synthesizer.continueSpeaking()
        isPaused = false
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        playbackStartTime = nil
        pausedTime = 0
        totalPausedDuration = 0
        currentText = ""
    }
    
    func rewind(seconds: TimeInterval = 3.0) {
        guard !currentText.isEmpty, let startTime = playbackStartTime else { return }
        
        // Calculate elapsed playback time (excluding paused time)
        var elapsedTime = Date().timeIntervalSince(startTime) - totalPausedDuration
        if isPaused && pausedTime > 0 {
            elapsedTime -= (Date().timeIntervalSince1970 - pausedTime)
        }
        
        // Calculate new playback time (rewind by specified seconds)
        let newElapsedTime = max(0, elapsedTime - seconds)
        
        // Estimate character position based on speech rate and time
        // Average speaking rate: ~150 words per minute = ~2.5 words per second
        // Average word length: ~5 characters
        // So roughly 12-13 characters per second at normal rate
        let baseCharactersPerSecond: Double = 12.5
        let rateMultiplier = Double(playbackSpeed.rate) / 0.375 // 0.375 is normal rate
        let charactersPerSecond = baseCharactersPerSecond * rateMultiplier
        
        let estimatedPosition = Int(newElapsedTime * charactersPerSecond)
        
        // Stop current playback and restart from estimated position
        synthesizer.stopSpeaking(at: .immediate)
        playFromPosition(text: currentText, startPosition: estimatedPosition)
    }
    
    func setSpeed(_ speed: TTSSpeed) {
        playbackSpeed = speed
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension BasicTTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
    }
}

// MARK: - TTSSpeed Enumeration

enum TTSSpeed: String, CaseIterable {
    case verySlow = "Very Slow (0.25x)"
    case slow = "Slow (0.5x)"
    case normal = "Normal (0.75x)"
    
    var displayName: String { rawValue }
    
    var rate: Float {
        switch self {
        case .verySlow: return 0.125  // 実際の0.25倍速 (0.5 × 0.25)
        case .slow: return 0.25       // 実際の0.5倍速 (0.5 × 0.5)
        case .normal: return 0.375    // 実際の0.75倍速 (0.5 × 0.75)
        }
    }
}