//
//  Decoder.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import Sphinx


public struct Hypotesis {
    
    public let text: String
    public let score: Int
    
    func isEmpty() -> Bool {
        return text == "" && score == 0
    }
}

func +(lhs: Hypotesis, rhs: Hypotesis) -> Hypotesis {
    return Hypotesis(text: lhs.text + " " + rhs.text, score: lhs.score + rhs.score)
}

func +(lhs: Hypotesis?, rhs: Hypotesis?) -> Hypotesis? {
    if let _lhs = lhs, let _rhs = rhs {
        return _lhs + _rhs
    } else {
        if let _lhs = lhs {
            return _lhs
        } else {
            return rhs
        }
    }
}


public class Decoder {
    
    private var psDecoder: COpaquePointer
    public var bufferSize: Int = 2048
    
    public init?(config: Config) {
        
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
    
    private func process_raw(data: NSData) -> CInt {
        //Sphinx expect words of 2 bytes but the NSFileHandle read one byte at time so the lenght of the data for sphinx is the half of the real one.
        let dataLenght = data.length <= 1 ? 1 : data.length / 2
        
        return ps_process_raw(psDecoder, UnsafePointer(data.bytes), dataLenght, SFalse, SFalse)
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
            
            //uttInSpeech flag when there are actual speech detected in the audio.
            var uttInSpeech = false
            start_utt()
            
            let hypotesis = fileHandle.reduceChunks(bufferSize, initial: nil, reducer: { (data: NSData, partialHyp: Hypotesis?) -> Hypotesis? in
                
                self.process_raw(data)
                
                var resultantHyp = partialHyp
                let inSpeech = self.in_sppech()
                
                if inSpeech && !uttInSpeech {
                    uttInSpeech = true
                }
                
                //If there is no speech and we detect speech before get an hypotesis
                if !inSpeech && uttInSpeech {
                    
                    self.end_utt()
                    resultantHyp = partialHyp + self.get_hyp()
                    
                    self.start_utt()
                    uttInSpeech = false
                }
                
                return resultantHyp
            })
            
            end_utt()
            fileHandle.closeFile()
            
            //Process any pending speech
            if uttInSpeech {
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
}