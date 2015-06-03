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

private enum SpeechStateEnum : Printable {
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
        assert(ps_free(psDecoder) == 0, "Can't free decoder, it's shared among instances")
    }
    
    
    private func process_raw(data: NSData) -> CInt {
        //Sphinx expect words of 2 bytes but the NSFileHandle read one byte at time so the lenght of the data for sphinx is the half of the real one.
        let dataLenght = data.length / 2
        let numberOfFrames = ps_process_raw(psDecoder, UnsafePointer(data.bytes), dataLenght, SFalse, SFalse)
        let hasSpeech = in_sppech()
        
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
    
    private func in_sppech() -> Bool {
        return ps_get_in_speech(psDecoder) == 1
    }
    
    private func start_utt() -> Bool {
        return ps_start_utt(psDecoder) == 0
    }
    
    private func end_utt() -> Bool {
        return ps_end_utt(psDecoder) == 0
    }
    
    private func get_hyp() -> Hypotesis? {
        var score: CInt = 0
        let string: UnsafePointer<CChar> = ps_get_hyp(psDecoder, &score)
        
        if let text = String.fromCString(string) {
            return Hypotesis(text: text, score: Int(score))
        } else {
            return nil
        }
    }
    
    private func hypotesisForSpeechAtPath (filePath: String) -> Hypotesis? {
        
        if let fileHandle = NSFileHandle(forReadingAtPath: filePath) {
            
            start_utt()
            
            let hypotesis = fileHandle.reduceChunks(bufferSize, initial: nil, reducer: { (data: NSData, partialHyp: Hypotesis?) -> Hypotesis? in
                
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
                return hypotesis + get_hyp()
            } else {
                return hypotesis
            }
            
        } else {
            return nil
        }
    }
    
    public func decodeSpeechAtPath (filePath: String, complete: (Hypotesis?) -> ()) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let hypotesis = self.hypotesisForSpeechAtPath(filePath)
            
            dispatch_async(dispatch_get_main_queue()) {
                complete(hypotesis)
            }
        }
    }
    
    public func startDecodingSpeech (utteranceComplete: (Hypotesis?) -> ()) {
        
        var error: NSErrorPointer = nil
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord, error: error)
        
        if error != nil {
            println("Error setting the shared AVAudioSession: \(error)")
            return
        }
        
        let tmpFileName = NSTemporaryDirectory()!.stringByAppendingPathComponent("TLSphinx-\(NSDate.timeIntervalSinceReferenceDate())")
        let tmpAudioFile = NSURL(string: tmpFileName)
        
        let settings: [NSObject : AnyObject] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVSampleRateKey:            16000.0,
            AVNumberOfChannelsKey:      1,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsBigEndianKey:  false,
            AVLinearPCMIsFloatKey:      false
        ]
        
        recorder = AVAudioRecorder(URL: tmpAudioFile, settings: settings, error: error)
        
        if error != nil {
            println("Error setting the audio recorder: \(error)")
            return
        }
        
        if recorder.record() {
            if let audioFileHandle = NSFileHandle(forReadingAtPath: tmpFileName) {
                
                start_utt()
                
                audioFileHandle.readabilityHandler = { (handler: NSFileHandle!) -> Void in
                    
                    self.process_raw(handler.availableData)
                    
                    if self.speechState == .Utterance {
                        self.end_utt()
                        utteranceComplete(self.get_hyp())
                        self.start_utt()
                    }
                }
            }
        }
    }
    
    public func stopDecodingSpeech () {
        recorder.stop()
        end_utt()
        
        recorder.deleteRecording()
        recorder = nil

    }
}