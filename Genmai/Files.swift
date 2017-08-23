//
//  Files.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import Result

public struct Files {
  public static func filesIn(directory:String) -> Result<[String], NSError> {
    return throwableToResult {
      //      print("ok what is directory mang \(directory)")
      return try FileManager.default.contentsOfDirectory(atPath: directory)
    }
  }
}
