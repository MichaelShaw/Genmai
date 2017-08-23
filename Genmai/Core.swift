//
//  Core.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import Result

public func throwableToResult<T>(block: (() throws -> T)) -> Result<T, NSError> {
  do {
    let r = try block()
    return Result.success(r)
  } catch let error as NSError {
    return Result.failure(error)
  }
}

public func throwableToOption<T>(block: (() throws -> T)) -> T? {
  do {
    let r = try block()
    return r
  } catch _ as NSError {
    return nil
  }
}


public struct Collections {
  public static func partition<T>(_ arr:[T], pred:(T) -> Bool) -> (matching:[T], nonMatching:[T]) {
    var matching = [T]()
    var nonMatching = [T]()
    
    for element in arr {
      if(pred(element)) {
        matching.append(element)
      } else {
        nonMatching.append(element)
      }
    }
    
    return (matching, nonMatching)
  }
}

public func timedPrint(_ msg:String) {
  let seconds = Double(Instant.now().msSinceReferenceDate) / Double(Instant.millisecondsInSecond)
  print("@\(Math.rounded3(seconds)): \(msg)")
}
