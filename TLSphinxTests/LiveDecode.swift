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
    
    let audioEngine = AVAudioEngine()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let inputNode = audioEngine.inputNode
        let bus = 0
        inputNode.installTapOnBus(bus, bufferSize: 2048, format: inputNode.inputFormatForBus(bus)) {
            (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
            println("sfdljk")
        }
        audioEngine.prepare()
        audioEngine.startAndReturnError(nil)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}
