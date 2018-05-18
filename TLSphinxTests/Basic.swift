//
//  TLSphinxTests.swift
//  TLSphinxTests
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import UIKit
import XCTest
import TLSphinx


class BasicTests: XCTestCase {
    
    func getModelPath() -> NSString? {
        return Bundle(for: BasicTests.self).path(forResource: "en-us", ofType: nil) as NSString?
    }
    
    func testConfig() {

        guard let modelPath = getModelPath() else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(Bundle.main)")
            return
        }

        let hmm = modelPath.appendingPathComponent("en-us")
        let lm = modelPath.appendingPathComponent("en-us.lm.dmp")
        let dict = modelPath.appendingPathComponent("cmudict-en-us.dict")
        
        let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict))
        XCTAssert(config != nil, "Pass")
    }
    
    func testDecoder() {
        
        guard let modelPath = getModelPath() else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(Bundle.main)")
            return
        }
            
        let hmm = modelPath.appendingPathComponent("en-us")
        let lm = modelPath.appendingPathComponent("en-us.lm.dmp")
        let dict = modelPath.appendingPathComponent("cmudict-en-us.dict")
        
        guard let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) else {
            XCTFail("Can't run test without a valid config")
            return
        }

        let decoder = Decoder(config:config)
        XCTAssert(decoder != nil, "Pass")
    }

    func testSpeechFromFile() {
        
        guard let modelPath = getModelPath() else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(Bundle.main)")
            return
        }

        let hmm = modelPath.appendingPathComponent("en-us")
        let lm = modelPath.appendingPathComponent("en-us.lm.dmp")
        let dict = modelPath.appendingPathComponent("cmudict-en-us.dict")
        
        guard let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) else {
            XCTFail("Can't run test without a valid config")
            return
        }

        guard let decoder = Decoder(config:config) else {
            XCTFail("Can't run test without a decoder")
            return
        }

        let audioFile = modelPath.appendingPathComponent("goforward.raw")
        let expectation = self.expectation(description: "Decode finish")
        
        try! decoder.decodeSpeech(atPath: audioFile) {
            
            if let hyp = $0 {
                
                print("Text: \(hyp.text) - Score: \(hyp.score)")
                XCTAssert(hyp.text == "go forward ten meters", "Pass")
                
            } else {
                XCTFail("Fail to decode audio")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: NSTimeIntervalSince1970)
    }

    func testAddWordToLenguageModel() {

        guard let modelPath = getModelPath() else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(Bundle.main)")
            return
        }

        let basicModelPath = (modelPath.appendingPathComponent("basic-lm") as NSString)
        let hmm = modelPath.appendingPathComponent("en-us")
        let lm = basicModelPath.appendingPathComponent("6844.lm")
        let dict = basicModelPath.appendingPathComponent("6844.dic")

        guard let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) else {
            XCTFail("Can't run test without a valid config")
            return
        }

        guard let decoder = Decoder(config:config) else {
            XCTFail("Can't run test without a decoder")
            return
        }

        let audioFile = modelPath.appendingPathComponent("goforward.raw")
        let expectation = self.expectation(description: "Decode finish")

        try! decoder.decodeSpeech(atPath: audioFile) { [unowned decoder] in

            if let hyp = $0 {

                print("Text: \(hyp.text) - Score: \(hyp.score)")
                XCTAssert(hyp.text == "GO FORWARD TEN", "Pass")

                try! decoder.add(words:[("METERS","M IY T ER Z")])

                try! decoder.decodeSpeech(atPath: audioFile) {
                    if let hyp = $0 {

                        print("Text: \(hyp.text) - Score: \(hyp.score)")
                        XCTAssert(hyp.text == "GO FORWARD TEN METERS", "Pass")
                    } else {
                        XCTFail("Fail to decode audio")
                    }

                    expectation.fulfill()
                }

            } else {
                XCTFail("Fail to decode audio")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: NSTimeIntervalSince1970)
    }
}
