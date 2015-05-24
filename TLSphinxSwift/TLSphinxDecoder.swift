//
//  TLSphinxDecoder.swift
//  TLSphinxSwift
//
//  Created by Bruno Berisso on 5/22/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import Sphinx


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
        
        // Create [UnsafeMutablePointer<Int8>] by strdup the original Strings
        var cArgs = args.flatMap { (name, value) -> [UnsafeMutablePointer<Int8>] in
            return [strdup(name),strdup(value)]
        }
        
        cmdLnConf = cmd_ln_parse_r(nil, ps_args(), CInt(cArgs.count), &cArgs, 1 as CInt)
        
        // Free the duplicated strings
        for cString in cArgs {
            free(cString)
        }
        
        if cmdLnConf == nil {
            return nil
        }
    }
}


public struct Hypotesis {
    let text: String
    let score: Int
}

public class Decoder {
    
    var psDecoder: COpaquePointer
    
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
    
    public func decodeSpeechAtPath (filePath: String) -> Hypotesis? {
        
        if let fileHandle = NSFileHandle(forReadingAtPath: filePath) {
            
            if ps_start_utt(psDecoder) != 0 {
                return nil
            }
            
            fileHandle.reduceChunks(512, initial: 0 as CInt, reducer: { (data: NSData, numberOfFrames: CInt) -> CInt in
                return ps_process_raw(self.psDecoder, unsafeBitCast(data.bytes, UnsafePointer<CShort>.self), data.length as size_t, 0 as CInt, 0 as CInt)
            })
            
            if ps_end_utt(psDecoder) == 0 {
                var score: CInt = 0
                if let text = String.fromCString(ps_get_hyp(psDecoder, &score)) {
                    return Hypotesis(text: text, score: Int(score))
                } else {
                    return Hypotesis(text: "", score: Int(score))
                }
                
            } else {
                return nil
            }
            
        } else {
            return nil
        }
        
    }
}