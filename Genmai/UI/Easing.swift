//
//  Easing.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

public struct Easing {
  public static func cubic(t:Double) -> Double {
    let ta = t - 1
    return ta * ta * ta + 1
  }
  
  public static let cubicFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.46, 0.33, 1)
  
  public static func quartic(t:Double) -> Double {
    let ta = t - 1
    return (ta * ta * ta * ta - 1) * -1
  }
  
  public static let quarticFunction = CAMediaTimingFunction(controlPoints: 0.23 ,0.66 ,0.19,1)
  
  public static func quintic(t:Double) -> Double {
    let ta = t - 1
    return (ta * ta * ta * ta * ta) + 1
  }
  
  public static let quinticFunction = CAMediaTimingFunction(controlPoints: 0.19, 0.73, 0.11, 1)
}
