//
//  Config.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import Sphinx

public class Config {
    
    var cmdLnConf: COpaquePointer
    
    public init?(args: (String,String)...) {
        
        // Create [UnsafeMutablePointer<Int8>].
        var cArgs = args.flatMap { (name, value) -> [UnsafeMutablePointer<Int8>] in
            //strdup move the strings to the heap and return a UnsageMutablePointer<Int8>
            return [strdup(name),strdup(value)]
        }
        
        cmdLnConf = cmd_ln_parse_r(nil, ps_args(), CInt(cArgs.count), &cArgs, STrue)
        
        if cmdLnConf == nil {
            return nil
        }
    }
}