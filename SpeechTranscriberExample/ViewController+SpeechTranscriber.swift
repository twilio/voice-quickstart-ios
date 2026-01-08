//
//  ViewController+SpeechTranscriber.swift
//  Twilio Voice Quickstart - SpeechTranscriberExample
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import Foundation
import Speech

extension ViewController {
    func setUpTranscriber() async throws {
        speechTranscriber = SpeechTranscriber(locale: Locale.current,
                                              transcriptionOptions: [],
                                              reportingOptions: [.volatileResults],
                                              attributeOptions: [.audioTimeRange])
        
        guard let speechTranscriber else {
            throw NSError(domain: "VoiceQuickStart", code: 1, userInfo: nil)
        }
        
        speechAnalyzer = SpeechAnalyzer(modules: [speechTranscriber])
        
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [speechTranscriber])
        
        do {
            try await ensureModel(transcriber: speechTranscriber, locale: Locale.current)
        } catch {
            print("Failed to ensure model")
            return
        }
        
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        
        guard let inputSequence else { return }
        
        try await speechAnalyzer?.start(inputSequence: inputSequence)
        
        recognizerTask = Task {
            do {
                for try await case let result in speechTranscriber.results {
                    let text = result.text

                    if result.isFinal {
                        // Update UI with final result
                    } else {
                        // Display volatile recognition result
                        print("Remote: \(String(text.characters))")
                        DispatchQueue.main.async() {
                            self.speechToTextLabel.isHidden = false
                            self.speechToTextLabel.text = String(text.characters)
                        }
                    }
                }
            } catch {
                print("Speech recognition failed")
            }
        }
    }
    
    func transcribe(buffer: AVAudioPCMBuffer?, format: AVAudioFormat?) async{
        guard let inputBuilder else {
            print("No input-builder")
            return
        }
        
        let input = AnalyzerInput(buffer: buffer!)
        inputBuilder.yield(input)
    }
    
    func stopTranscribing() async throws {
        inputBuilder?.finish()
        try await speechAnalyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil
        self.speechToTextLabel.isHidden = true
    }
    
    func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw NSError(domain: "VoiceQuickStart", code: 1, userInfo: nil)
        }
        
        if await installed(locale: locale) {
            return
        } else {
            try await downloadIfNeeded(for: speechTranscriber!)
        }
    }
        
    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
    
    func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await downloader.downloadAndInstall()
        }
    }
}
