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
