//
//  Instant.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import Foundation

public typealias InstantI = Int64



public struct Instant {
  var raw: Int64
  
  public static let millisecondsInSecond : Int64 = 1000
  
  public init(date:Date) {
    self.raw = Int64(date.timeIntervalSinceReferenceDate * Double(Instant.millisecondsInSecond))
  }
  
  public init(milliseconds: Int64) {
    self.raw = milliseconds
  }
  
  public init(raw: Int64) {
    self.raw = raw
  }
  
  public var date : Date {
    get {
      return Date(timeIntervalSinceReferenceDate: TimeInterval(raw) / TimeInterval(Instant.millisecondsInSecond))
    }
  }
  
  public var msSinceReferenceDate : Int64 {
    get { return self.raw }
  }
}

extension Instant : Equatable {}
extension Instant : Comparable {}

public extension Instant {
  static func sameSecond(_ lhs : Instant, _ rhs : Instant) -> Bool {
    let lhsSeconds = (lhs.raw / millisecondsInSecond)
    let rhsSeconds = (rhs.raw / millisecondsInSecond)
    return lhsSeconds == rhsSeconds
  }
  
  static func <(lhs: Instant, rhs: Instant) -> Bool {
    return lhs.raw < rhs.raw
  }
  
  static func ==(lhs: Instant, rhs: Instant) -> Bool {
    return lhs.raw == rhs.raw
  }
  
  static func now() -> Instant {
    return Instant(date: Date())
  }
}
