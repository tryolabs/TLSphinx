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
    
    func getModelPath() -> String? {
        return Bundle(for: LiveDecode.self).path(forResource: "en-us", ofType: nil)
    }

    func testAVAudioRecorder() {
        
        if let modelPath = getModelPath() {
            
            let hmm = (modelPath as NSString).appendingPathComponent("en-us")
            let lm = (modelPath as NSString).appendingPathComponent("en-us.lm.dmp")
            let dict = (modelPath as NSString).appendingPathComponent("cmudict-en-us.dict")
            
            if let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) {
                
                config.showDebugInfo = false
                
                if let decoder = Decoder(config:config) {
                    decoder.startDecodingSpeech { (hyp) -> () in
                        print("Utterance: \(hyp)")
                    }
                    
                    let theExpectation = expectation(description: "")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: DispatchTime.now().rawValue) + Double(Int64(15.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                        decoder.stopDecodingSpeech()
                        theExpectation.fulfill()
                    }
                    
                    waitForExpectations(timeout: NSTimeIntervalSince1970, handler: nil)
                }
                
            } else {
                XCTFail("Can't run test without a valid config")
            }
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(Bundle.main)")
        }
    }

}
