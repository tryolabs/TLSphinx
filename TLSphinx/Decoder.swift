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


private enum SpeechStateEnum : CustomStringConvertible {
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


private extension AVAudioPCMBuffer {

    func toNSDate() -> Data {
        let channels = UnsafeBufferPointer(start: int16ChannelData, count: 1)
        let ch0Data = Data(bytes: UnsafeMutablePointer<Int16>(channels[0]), count:Int(frameCapacity * format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }

}


open class Decoder {
    
    fileprivate var psDecoder: OpaquePointer?
    fileprivate var engine: AVAudioEngine!
    fileprivate var speechState: SpeechStateEnum
    
    open var bufferSize: Int = 2048
    
    public init?(config: Config) {
        
        speechState = .silence
        
        if config.cmdLnConf != nil{
            psDecoder = ps_init(config.cmdLnConf)
            
            if psDecoder == nil {
                return nil
            }
            
        } else {
            psDecoder = nil
            return nil
        }
    }
    
    deinit {
        let refCount = ps_free(psDecoder)
        assert(refCount == 0, "Can't free decoder, it's shared among instances")
    }
    
    fileprivate func process_raw(_ data: Data) -> CInt {
        //Sphinx expect words of 2 bytes but the NSFileHandle read one byte at time so the lenght of the data for sphinx is the half of the real one.
        let dataLenght = data.count / 2
        let numberOfFrames = ps_process_raw(psDecoder, (data as NSData).bytes.bindMemory(to: int16.self, capacity: data.count), dataLenght, SFalse, SFalse)
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
        return ps_get_in_speech(psDecoder) == 1
    }
    
    fileprivate func start_utt() -> Bool {
        return ps_start_utt(psDecoder) == 0
    }
    
    fileprivate func end_utt() -> Bool {
        return ps_end_utt(psDecoder) == 0
    }
    
    fileprivate func get_hyp() -> Hypothesis? {
        var score: CInt = 0
        let string: UnsafePointer<CChar> = ps_get_hyp(psDecoder, &score)
        
        if let text = String(validatingUTF8: string) {
            return Hypothesis(text: text, score: Int(score))
        } else {
            return nil
        }
    }
    
    fileprivate func hypotesisForSpeechAtPath (_ filePath: String) -> Hypothesis? {
        
        if let fileHandle = FileHandle(forReadingAtPath: filePath) {
            
            start_utt()
            
            let hypothesis = fileHandle.reduceChunks(bufferSize, initial: nil, reducer: { [unowned self] (data: Data, partialHyp: Hypothesis?) -> Hypothesis? in
                
                self.process_raw(data)
                
                var resultantHyp = partialHyp
                if self.speechState == .utterance {
                    
                    self.end_utt()
                    resultantHyp = partialHyp + self.get_hyp()
                    self.start_utt()
                }
                
                return resultantHyp
            })
            
            end_utt()
            fileHandle.closeFile()
            
            //Process any pending speech
            if speechState == .speech {
                return hypothesis + get_hyp()
            } else {
                return hypothesis
            }
            
        } else {
            return nil
        }
    }
    
    open func decodeSpeechAtPath (_ filePath: String, complete: @escaping (Hypothesis?) -> ()) {
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            
            let hypothesis = self.hypotesisForSpeechAtPath(filePath)
            
            DispatchQueue.main.async {
                complete(hypothesis)
            }
        }
    }
    
    open func startDecodingSpeech (_ utteranceComplete: @escaping (Hypothesis?) -> ()) {

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
        } catch let error as NSError {
            print("Error setting the shared AVAudioSession: \(error)")
            return
        }

        engine = AVAudioEngine()

        guard let input = engine.inputNode else {
            print("Can't get input node")
            return
        }

        let formatIn = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: false)
        engine.connect(input, to: engine.outputNode, format: formatIn)

        input.installTap(onBus: 0, bufferSize: 4096, format: formatIn, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

            let audioData = buffer.toNSDate()
            self.process_raw(audioData)

            if self.speechState == .utterance {

                self.end_utt()
                let hypothesis = self.get_hyp()
                
                DispatchQueue.main.async(execute: { 
                    utteranceComplete(hypothesis)
                })

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
        }
    }

    open func stopDecodingSpeech () {
        engine.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.reset()
        engine = nil
    }
}
