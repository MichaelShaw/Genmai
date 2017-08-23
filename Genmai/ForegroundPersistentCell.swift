//
//  ForegroundPersistentCell.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import Result
import BrightFutures

public typealias PostPersistF = (String, Data) -> ()

public class ForegroundPersistentCell<T> {
  let persistenceQueue:DispatchQueue
  
  let key:String
  let userDefaults:UserDefaults
  
  let serialize: (T) -> Data
  let deserialize: (Data) -> T?
  
  private var value : T
  
  public init(persistenceQueue:DispatchQueue,
              key:String,
              defaultValue: T,
              userDefaults:UserDefaults,
              serialize: @escaping (T) -> Data,
              deserialize: @escaping (Data) -> T?) {
    self.persistenceQueue = persistenceQueue
    self.key = key
    self.userDefaults = userDefaults
    self.serialize = serialize
    self.deserialize = deserialize
    self.value = defaultValue
    
    if let currentData = userDefaults.data(forKey: key) {
      if let startingValue = deserialize(currentData) {
        self.value = startingValue
      } else {
        let str = String(data: currentData, encoding: String.Encoding.utf8)
        timedPrint("FPC :: deserialization failed :-( data string -> \(String(describing: str))")
      }
    }
  }
  
  public func read() -> T {
    return value
  }
  
  public func tenativeWrite<ReturnValue>(modifyF:(T) -> (T?, ReturnValue)) -> (T, ReturnValue, Future<T, NoError>) { // future is just for persistence
    let oldValue = self.value
    let (newValue, returnValue) = modifyF(oldValue)
    
    if let nv = newValue {
      self.value = nv
      return (nv, returnValue, persist(newValue: nv))
    } else {
      return (oldValue, returnValue, Future(value: oldValue))
    }
  }
  
  public func write<ReturnValue>(modifyF:(T) -> (T, ReturnValue)) -> (T, ReturnValue, Future<T, NoError>) { // future is just for persistence
    let oldValue = self.value
    let (newValue, returnValue) = modifyF(oldValue)
    self.value = newValue
    return (newValue, returnValue, persist(newValue: newValue))
  }
  
  private func persist(newValue:T) -> Future<T, NoError> {
    return persistenceQueue.asyncValue { _ in
      let data = self.serialize(newValue)
      
      self.userDefaults.setValue(data, forKey: self.key)
      self.userDefaults.synchronize()
      
      return newValue
    }
  }
}
