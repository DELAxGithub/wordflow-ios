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
    var playbackSpeed: TTSSpeed = .normal
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MVP: Full text playback only
    func playFullText(_ text: String) {
        stop() // Stop any current playback
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // US English fixed
        utterance.rate = playbackSpeed.rate
        
        isPlaying = true
        isPaused = false
        synthesizer.speak(utterance)
    }
    
    func pause() {
        guard isPlaying && !isPaused else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
    }
    
    func resume() {
        guard isPlaying && isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
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
    case verySlow = "0.25x"
    case slow = "0.5x"
    case normal = "0.75x"
    case fast = "1.0x"
    
    var displayName: String { rawValue }
    
    var rate: Float {
        switch self {
        case .verySlow: return 0.25
        case .slow: return 0.5
        case .normal: return 0.75
        case .fast: return 1.0
        }
    }
}