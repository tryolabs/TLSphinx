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
    case Silence
    case Speech
    case Utterance
    
    var description: String {
        get {
            switch(self) {
            case .Silence:
                return "Silence"
            case .Speech:
                return "Speech"
            case .Utterance:
                return "Utterance"
            }
        }
    }
}

public class Decoder {
    
    private var psDecoder: COpaquePointer
    private var recorder: AVAudioRecorder!
    private var speechState: SpeechStateEnum
    
    public var bufferSize: Int = 2048
    
    public init?(config: Config) {
        
        speechState = .Silence
        
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
    
    private func process_raw(data: NSData) -> CInt {
        //Sphinx expect words of 2 bytes but the NSFileHandle read one byte at time so the lenght of the data for sphinx is the half of the real one.
        let dataLenght = data.length / 2
        let numberOfFrames = ps_process_raw(psDecoder, UnsafePointer(data.bytes), dataLenght, SFalse, SFalse)
        let hasSpeech = in_speech()
        
        switch (speechState) {
        case .Silence where hasSpeech:
            speechState = .Speech
        case .Speech where !hasSpeech:
            speechState = .Utterance
        case .Utterance where !hasSpeech:
            speechState = .Silence
        default:
            break
        }
        
        return numberOfFrames
    }
    
    private func in_speech() -> Bool {
        return ps_get_in_speech(psDecoder) == 1
    }
    
    private func start_utt() -> Bool {
        return ps_start_utt(psDecoder) == 0
    }
    
    private func end_utt() -> Bool {
        return ps_end_utt(psDecoder) == 0
    }
    
    private func get_hyp() -> Hypothesis? {
        var score: CInt = 0
        let string: UnsafePointer<CChar> = ps_get_hyp(psDecoder, &score)
        
        if let text = String.fromCString(string) {
            return Hypothesis(text: text, score: Int(score))
        } else {
            return nil
        }
    }
    
    private func hypotesisForSpeechAtPath (filePath: String) -> Hypothesis? {
        
        if let fileHandle = NSFileHandle(forReadingAtPath: filePath) {
            
            start_utt()
            
            let hypothesis = fileHandle.reduceChunks(bufferSize, initial: nil, reducer: { (data: NSData, partialHyp: Hypothesis?) -> Hypothesis? in
                
                self.process_raw(data)
                
                var resultantHyp = partialHyp
                if self.speechState == .Utterance {
                    
                    self.end_utt()
                    resultantHyp = partialHyp + self.get_hyp()
                    self.start_utt()
                }
                
                return resultantHyp
            })
            
            end_utt()
            fileHandle.closeFile()
            
            //Process any pending speech
            if speechState == .Speech {
                return hypothesis + get_hyp()
            } else {
                return hypothesis
            }
            
        } else {
            return nil
        }
    }
    
    public func decodeSpeechAtPath (filePath: String, complete: (Hypothesis?) -> ()) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let hypothesis = self.hypotesisForSpeechAtPath(filePath)
            
            dispatch_async(dispatch_get_main_queue()) {
                complete(hypothesis)
            }
        }
    }
    
    public func startDecodingSpeech (utteranceComplete: (Hypothesis?) -> ()) {
        
        let error: NSErrorPointer = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
        } catch let error1 as NSError {
            error.memory = error1
        }
        
        if error != nil {
            print("Error setting the shared AVAudioSession: \(error)")
            return
        }
        
        let tmpFileName = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("TLSphinx-\(NSDate.timeIntervalSinceReferenceDate())")
        let tmpAudioFile = NSURL(string: tmpFileName)
        
        let settings: [String : AnyObject] = [
            AVFormatIDKey:              UInt(kAudioFormatLinearPCM),
            AVSampleRateKey:            16000.0,
            AVNumberOfChannelsKey:      1,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsBigEndianKey:  false,
            AVLinearPCMIsFloatKey:      false
        ]
        
        do {
            recorder = try AVAudioRecorder(URL: tmpAudioFile!, settings: settings)
        } catch let error1 as NSError {
            error.memory = error1
            recorder = nil
        }
        
        if error != nil {
            print("Error setting the audio recorder: \(error)")
            return
        }
        
        if recorder.record() {
            if let audioFileHandle = NSFileHandle(forReadingAtPath: tmpFileName) {
                
                start_utt()
                
                audioFileHandle.readabilityHandler = { (handler: NSFileHandle) -> Void in
                    
                    let audioData  = handler.availableData
                    
                    if audioData.length > 0 {
                        self.process_raw(audioData)
                        
                        if self.speechState == .Utterance {
                            self.end_utt()
                            utteranceComplete(self.get_hyp())
                            self.start_utt()
                        }
                    }
                }
            }
        }
    }
    
    public func stopDecodingSpeech () {
        recorder.stop()
        recorder.deleteRecording()
        recorder = nil
    }
}