//
//  LiveDecode.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import UIKit
import XCTest
import AVFoundation
import TLSphinx

class LiveDecode: XCTestCase {
    
    func getModelPath() -> NSString? {
        return Bundle(for: LiveDecode.self).path(forResource: "en-us", ofType: nil) as NSString?
    }

    func testAVAudioRecorder() {
        
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

        config.showDebugInfo = false
        
        guard let decoder = Decoder(config:config) else {
            XCTFail("Can't run test without a decoder")
            return
        }

        try! decoder.startDecodingSpeech { print("Utterance: \(String(describing: $0))") }

        let theExpectation = expectation(description: "")
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: DispatchTime.now().rawValue) + Double(Int64(15.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            decoder.stopDecodingSpeech()
            theExpectation.fulfill()
        }
        
        waitForExpectations(timeout: NSTimeIntervalSince1970)
    }
}
