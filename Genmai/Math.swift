//
//  Math.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import Foundation


public struct Math {
  public static func modulusWithoutSign(_ a:Int, n:Int) -> Int {
    return (a % (n + n)) % n
  }
  
  public static func modulusWithoutSign(_ a:Int64, n:Int64) -> Int64 {
    return (a % (n + n)) % n
  }
  
  public static func modulusWithoutSign(_ a:Int32, n:Int32) -> Int32 {
    return (a % (n + n)) % n
  }

  public static func modulusWithoutSign(_ a:UInt, n:UInt) -> UInt {
    
    let aces = [1,2,3]
    
    
    return (a % (n + n)) % n
  }
  
  public static func modulusWithoutSign(_ a:Double, n:Double) -> Double {
    return a.truncatingRemainder(dividingBy: n)
  }
  
  public static func rounded3(_ d:Double) -> String {
    return String(format: "%.3f", d)
  }
}
