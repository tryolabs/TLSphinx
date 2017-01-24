//
//  Config.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import Sphinx.Base

public final class Config {
    
    var cmdLnConf: OpaquePointer?
    fileprivate var cArgs: [UnsafeMutablePointer<Int8>?]
    
    public init?(args: (String,String)...) {
        
        // Create [UnsafeMutablePointer<Int8>].
        cArgs = args.flatMap { (name, value) -> [UnsafeMutablePointer<Int8>?] in
            //strdup move the strings to the heap and return a UnsageMutablePointer<Int8>
            return [strdup(name),strdup(value)]
        }
        
        cmdLnConf = cmd_ln_parse_r(nil, ps_args(), CInt(cArgs.count), &cArgs, STrue32)
        
        if cmdLnConf == nil {
            return nil
        }
    }
    
    deinit {
        for cString in cArgs {
            free(cString)
        }
        
        cmd_ln_free_r(cmdLnConf)
    }
    
    
    public var showDebugInfo: Bool {
        get {
            if cmdLnConf != nil {
                return cmd_ln_str_r(cmdLnConf, "-logfn") == nil
            } else {
                return false
            }
        }
        set {
            if cmdLnConf != nil {
                if newValue {
                    cmd_ln_set_str_r(cmdLnConf, "-logfn", nil)
                } else {
                    cmd_ln_set_str_r(cmdLnConf, "-logfn", "/dev/null")
                }
            }
        }
    }
}
