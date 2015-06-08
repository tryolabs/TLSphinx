//
//  Hypotesis.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 6/1/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation

public struct Hypotesis {
    public let text: String
    public let score: Int
}

extension Hypotesis : Printable {
    
    public var description: String {
        get {
            return "Text: \(text) - Score: \(score)"
        }
    }
    
}

func +(lhs: Hypotesis, rhs: Hypotesis) -> Hypotesis {
    return Hypotesis(text: lhs.text + " " + rhs.text, score: (lhs.score + rhs.score) / 2)
}

func +(lhs: Hypotesis?, rhs: Hypotesis?) -> Hypotesis? {
    if let _lhs = lhs, let _rhs = rhs {
        return _lhs + _rhs
    } else {
        if let _lhs = lhs {
            return _lhs
        } else {
            return rhs
        }
    }
}