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
        return NSBundle(forClass: LiveDecode.self).pathForResource("en-us", ofType: nil)
    }

    func testAVAudioRecorder() {
        
        if let modelPath = getModelPath() {
            
            let hmm = (modelPath as NSString).stringByAppendingPathComponent("en-us")
            let lm = (modelPath as NSString).stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = (modelPath as NSString).stringByAppendingPathComponent("cmudict-en-us.dict")
            
            if let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) {
                
                config.showDebugInfo = false
                
                if let decoder = Decoder(config:config) {
                    decoder.startDecodingSpeech { (hyp) -> () in
                        print("Utterance: \(hyp)")
                    }
                    
                    let expectation = expectationWithDescription("")
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(15.0 * Double(NSEC_PER_SEC))) , dispatch_get_main_queue(), { () -> Void in
                        decoder.stopDecodingSpeech()
                        expectation.fulfill()
                    })
                    
                    waitForExpectationsWithTimeout(NSTimeIntervalSince1970, handler: nil)
                }
                
            } else {
                XCTFail("Can't run test without a valid config")
            }
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
    }

}
