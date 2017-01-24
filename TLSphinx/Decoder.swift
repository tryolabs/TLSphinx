//
//  Decoder.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import AVFoundation
import Sphinx


fileprivate enum SpeechStateEnum : CustomStringConvertible {
    case silence
    case speech
    case utterance
    
    var description: String {
        get {
            switch(self) {
            case .silence:
                return "Silence"
            case .speech:
                return "Speech"
            case .utterance:
                return "Utterance"
            }
        }
    }
}


fileprivate extension AVAudioPCMBuffer {

    func toData() -> Data {
        let channels = UnsafeBufferPointer(start: int16ChannelData, count: 1)
        let ch0Data = Data(bytes: UnsafeMutablePointer<int16>(channels[0]),
                           count: Int(frameCapacity * format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }

}


public enum DecodeErrors : Error {
    case CantReadSpeachFile(String)
    case CantSetAudioSession(NSError)
    case NoAudioInputAvailable
    case CantStartAudioEngine(NSError)
    case CantAddWordsWhileDecodeingSpeech
}


public final class Decoder {
    
    fileprivate var psDecoder: OpaquePointer?
    fileprivate var engine: AVAudioEngine!
    fileprivate var speechState: SpeechStateEnum
    
    public init?(config: Config) {
        
        speechState = .silence
        psDecoder = config.cmdLnConf.flatMap(ps_init)

        if psDecoder == nil {
            return nil
        }
    }
    
    deinit {
        let refCount = ps_free(psDecoder)
        assert(refCount == 0, "Can't free decoder because it's shared among instances")
    }
    
    @discardableResult fileprivate func process_raw(_ data: Data) -> CInt {

        let dataLenght = data.count / 2
        let numberOfFrames = data.withUnsafeBytes { (bytes : UnsafePointer<Int16>) -> Int32 in
            ps_process_raw(psDecoder, bytes, dataLenght, SFalse32, SFalse32)
        }
        let hasSpeech = in_speech()
        
        switch (speechState) {
        case .silence where hasSpeech:
            speechState = .speech
        case .speech where !hasSpeech:
            speechState = .utterance
        case .utterance where !hasSpeech:
            speechState = .silence
        default:
            break
        }
        
        return numberOfFrames
    }
    
    fileprivate func in_speech() -> Bool {
        return ps_get_in_speech(psDecoder) == STrue
    }
    
    @discardableResult fileprivate func start_utt() -> Bool {
        return ps_start_utt(psDecoder) == 0
    }
    
    @discardableResult fileprivate func end_utt() -> Bool {
        return ps_end_utt(psDecoder) == 0
    }
    
    fileprivate func get_hyp() -> Hypothesis? {
        var score: int32 = 0

        guard let string = ps_get_hyp(psDecoder, &score) else {
            return nil
        }

        if let text = String(validatingUTF8: string) {
            return Hypothesis(text: text, score: Int(score))
        } else {
            return nil
        }
    }

    fileprivate func hypotesisForSpeech (inFile fileHandle: FileHandle) -> Hypothesis? {

        start_utt()

        let hypothesis = fileHandle.reduceChunks(2048, initial: nil, reducer: {
            (data: Data, partialHyp: Hypothesis?) -> Hypothesis? in

            process_raw(data)

            var resultantHyp = partialHyp
            if speechState == .utterance {

                end_utt()
                resultantHyp = partialHyp + get_hyp()
                start_utt()
            }

            return resultantHyp
        })

        end_utt()

        //Process any pending speech
        if speechState == .speech {
            return hypothesis + get_hyp()
        } else {
            return hypothesis
        }
    }

    public func decodeSpeech (atPath filePath: String, complete: @escaping (Hypothesis?) -> ()) throws {

        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            throw DecodeErrors.CantReadSpeachFile(filePath)
        }

        DispatchQueue.global().async {
            let hypothesis = self.hypotesisForSpeech(inFile:fileHandle)
            fileHandle.closeFile()
            DispatchQueue.main.async {
                complete(hypothesis)
            }
        }
    }
    
    public func startDecodingSpeech (_ utteranceComplete: @escaping (Hypothesis?) -> ()) throws {

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
        } catch let error as NSError {
            print("Error setting the shared AVAudioSession: \(error)")
            throw DecodeErrors.CantSetAudioSession(error)
        }

        engine = AVAudioEngine()

        guard let input = engine.inputNode else {
            throw DecodeErrors.NoAudioInputAvailable
        }

        let formatIn = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: false)
        engine.connect(input, to: engine.outputNode, format: formatIn)

        input.installTap(onBus: 0, bufferSize: 4096, format: formatIn, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

            let audioData = buffer.toDate()
            self.process_raw(audioData)

            if self.speechState == .utterance {

                self.end_utt()
                let hypothesis = self.get_hyp()

                DispatchQueue.main.async {
                    utteranceComplete(hypothesis)
                }

                self.start_utt()
            }
        })

        engine.mainMixerNode.outputVolume = 0.0
        engine.prepare()

        start_utt()

        do {
            try engine.start()
        } catch let error as NSError {
            end_utt()
            print("Can't start AVAudioEngine: \(error)")
            throw DecodeErrors.CantStartAudioEngine(error)
        }
    }

    public func stopDecodingSpeech () {
        engine.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.reset()
        engine = nil
    }
}
