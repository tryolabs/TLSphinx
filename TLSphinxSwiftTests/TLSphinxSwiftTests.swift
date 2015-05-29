//
//  TLSphinxSwiftTests.swift
//  TLSphinxSwiftTests
//
//  Created by Bruno Berisso on 5/19/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import UIKit
import XCTest
import TLSphinxSwift


class TLSphinxSwiftTests: XCTestCase {
    
    func getModelPath() -> String? {
        return NSBundle(forClass: TLSphinxSwiftTests.self).pathForResource("en-us", ofType: nil)
    }
    
    func testConfig() {
        
        if let modelPath = getModelPath() {
            
            let hmm = modelPath.stringByAppendingPathComponent("en-us")
            let lm = modelPath.stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = modelPath.stringByAppendingPathComponent("cmudict-en-us.dict")
            
            let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict))
            
            XCTAssert(config != nil, "Pass")
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
    }
    
    func testDecoder() {
        
        if let modelPath = getModelPath() {
            
            let hmm = modelPath.stringByAppendingPathComponent("en-us")
            let lm = modelPath.stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = modelPath.stringByAppendingPathComponent("cmudict-en-us.dict")
            
            if let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) {
                let decoder = Decoder(config:config)
                
                XCTAssert(decoder != nil, "Pass")
            } else {
                XCTFail("Can't run test without a valid config")
            }
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
    }
    
    func testSpeechFromFile() {
        
        if let modelPath = getModelPath() {
            
            let hmm = modelPath.stringByAppendingPathComponent("en-us")
            let lm = modelPath.stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = modelPath.stringByAppendingPathComponent("cmudict-en-us.dict")
            
            if let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) {
                if let decoder = Decoder(config:config) {
                    
                    let audioFile = modelPath.stringByAppendingPathComponent("goforward.raw")
                    
                    let expectation = expectationWithDescription("Decode finish")
                    decoder.decodeSpeechAtPath(audioFile) {
                        
                        if let hyp = $0 {
                            
                            println("Text: \(hyp.text) - Score: \(hyp.score)")
                            XCTAssert(hyp.text == "go forward ten meters", "Pass")
                            
                        } else {
                            XCTFail("Fail to decode audio")
                        }
                        
                        expectation.fulfill()
                    }
                    
                    waitForExpectationsWithTimeout(NSTimeIntervalSince1970, handler: { (_) -> Void in
                        
                    })
                    
                } else {
                    XCTFail("Can't run test without a decoder")
                }
                
            } else {
                XCTFail("Can't run test without a valid config")
            }
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
        
    }
}
