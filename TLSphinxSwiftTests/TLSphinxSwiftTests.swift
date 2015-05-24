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
    
    func testConfig() {
        
        if let modelPath = NSBundle(forClass: TLSphinxSwiftTests.self).pathForResource("en-us", ofType: nil) {
            
            let hmm = modelPath.stringByAppendingPathComponent("en-us")
            let lm = modelPath.stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = modelPath.stringByAppendingPathComponent("cmudict-en-us.dict")
            
            let c = Config(args:
                ("-hmm", hmm),
                ("-lm", lm),
                ("-dict", dict))
            
            XCTAssert(c != nil, "Pass")
            
        } else {
            XCTFail("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
