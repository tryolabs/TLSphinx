//
//  TLSphinxDecoder.swift
//  TLSphinxSwift
//
//  Created by Bruno Berisso on 5/22/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import Sphinx

let STrue: CInt = 1
let SFalse: CInt = 0

extension NSFileHandle {
    
    func reduceChunks<T>(size: Int, initial: T, reducer: (NSData, T) -> T) -> T {
        
        var reduceValue = initial
        var chuckData = readDataOfLength(size)
        
        while chuckData.length > 0 {
            reduceValue = reducer(chuckData, reduceValue)
            chuckData = readDataOfLength(size)
        }
        
        return reduceValue
    }
    
}


public class Config {
    
    var cmdLnConf: COpaquePointer
    
    public init?(args: (String,String)...) {
        
        // Create [UnsafeMutablePointer<Int8>].
        var cArgs = args.flatMap { (name, value) -> [UnsafeMutablePointer<Int8>] in
            //strdup move the strings to the heap and return a UnsageMutablePointer<Int8>
            return [strdup(name),strdup(value)]
        }
        
        cmdLnConf = cmd_ln_parse_r(nil, ps_args(), CInt(cArgs.count), &cArgs, STrue)
        
        if cmdLnConf == nil {
            return nil
        }
    }
}


public struct Hypotesis {
    
    public let text: String
    public let score: Int
    
    func isEmpty() -> Bool {
        return text == "" && score == 0
    }
}

func +(lhs: Hypotesis, rhs:Hypotesis) -> Hypotesis {
    return Hypotesis(text: lhs.text + " " + rhs.text, score: lhs.score + rhs.score)
}


public class Decoder {
    
    private var psDecoder: COpaquePointer
    public var bufferSize: Int = 2048
    
    public init?(config : Config) {
        
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
        return ps_process_raw(psDecoder, unsafeBitCast(data.bytes, UnsafePointer<CShort>.self), data.length / 2, SFalse, SFalse)
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
    
    public func decodeSpeechAtPath (filePath: String) -> Hypotesis? {
        
        if let fileHandle = NSFileHandle(forReadingAtPath: filePath) {
            
            var uttInSpeech = false
            start_utt()
            
            let hypotesis = fileHandle.reduceChunks(bufferSize, initial: nil, reducer: { (data: NSData, partialHyp: Hypotesis?) -> Hypotesis? in
                
                self.process_raw(data)
                
                var resultantHyp = partialHyp
                let inSpeech = self.in_sppech()
                
                if inSpeech && !uttInSpeech {
                    uttInSpeech = true
                }
                
                if !inSpeech && uttInSpeech {
                    
                    self.end_utt()
                    
                    if let newHyp = self.get_hyp() {
                        if let previousHyp = partialHyp {
                            resultantHyp = previousHyp + newHyp
                        } else {
                            resultantHyp = newHyp
                        }
                    }
                    
                    self.start_utt()
                    uttInSpeech = false
                }
                
                return resultantHyp
            })
            
            end_utt()
            fileHandle.closeFile()
            
            if uttInSpeech {
                if let newHyp = get_hyp() {
                    if let previousHyp = hypotesis {
                        return previousHyp + newHyp
                    } else {
                        return newHyp
                    }
                }
            }
            
            return hypotesis
            
        } else {
            return nil
        }
        
    }
}