//
//  NSFileHandle+Extension.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation

let STrue: CInt = 1
let SFalse: CInt = 0

extension FileHandle {
    
    func reduceChunks<T>(_ size: Int, initial: T, reducer: (Data, T) -> T) -> T {
        
        var reduceValue = initial
        var chuckData = readData(ofLength: size)
        
        while chuckData.count > 0 {
            reduceValue = reducer(chuckData, reduceValue)
            chuckData = readData(ofLength: size)
        }
        
        return reduceValue
    }
    
}
