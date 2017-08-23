//
//  SimpeLog.swift
//  TickTock
//
//  Created by Michael Shaw on 2/06/2016.
//  Copyright © 2016 Jaidev Soin & Michael Shaw. All rights reserved.
//

import Result
import Foundation
import BrightFutures
import Gzip

public typealias LoggingF = (String) -> () // sink

public class OpenLogFile : CustomStringConvertible {
  var logFile:LogFile
  var handle:FileHandle
  var lastLoggedInstant : Instant?
  
  init(logFile:LogFile, handle:FileHandle) {
    self.logFile = logFile
    self.handle = handle
  }
  
  public var description: String {
    return "OpenLogFile(lastLoggedInstant: \(String(describing: lastLoggedInstant)), logFile:\(logFile))"
  }
  
  public static func openAt(path:String) -> Result<OpenLogFile, LoggingTargetFailure> {
    if !FileManager.default.fileExists(atPath: path) {
      let writeResult = throwableToResult {
        try "".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
      }
      if let error = writeResult.error {
        return Result.failure(.CouldntWriteTo(path:path, error:error))
      }
    }
    
    if let fileHandle = FileHandle(forWritingAtPath: path) {
      fileHandle.seekToEndOfFile()
      
      if let logFile = SimpleLog.logFileFor(path: path) {
        return Result.success(OpenLogFile(logFile: logFile, handle: fileHandle))
      } else {
        return Result.failure(.CouldntCreateLogFileDespiteSuccessfulWrite(path:path))
      }
    } else {
      return Result.failure(.CouldntOpenFileHandle(path:path))
    }
  }
}

public class LogFile : Hashable, CustomStringConvertible {
  var name:String
  var path:String
  var size:UInt64 // NSFileSize
  var modifiedAt:NSDate // NSFileModificationDate
  
  init(path:String, size:UInt64, modifiedAt:NSDate) {
    self.name = (path as NSString).lastPathComponent
    self.path = path
    self.size = size
    self.modifiedAt = modifiedAt
  }
  
  public var hashValue: Int {
    get {
      return path.hashValue
    }
  }
  
  public var description: String {
    return "LogFile(\(path), size: \(size), modified: \(modifiedAt))"
  }
}

extension LogFile : Equatable {}
public func ==(lhs: LogFile, rhs: LogFile) -> Bool {
  return lhs.path == rhs.path
}

typealias NamingF = (Instant, [LogFile]) -> String // date and existing log files is considered sufficient 'context' to make an arbitrary logging decision
typealias RetainF = ([LogFile]) -> [LogFile]
typealias KeepTargetF = (OpenLogFile, Instant) -> Bool
typealias SortF = (LogFile, LogFile) -> Bool

public class Logger {
  public static let nullLogging:LoggingF = { _ in return () }
  
  // root directory
  var targetLogFile:OpenLogFile?
  
  // cleanup
  let loggingQueue:DispatchQueue
  
  let baseDirectory:String
  
  let namingF: NamingF // obviously needed
  let retainF: RetainF // allows deleting through exclusion
  let keepTargetF: KeepTargetF // needed to allow runtime size limiting of current file (e.g. files can only be 1MB)
  let sortF: SortF // needed for snapshots
  
  let printLogs:Bool
  
  init(baseDirectory:String, serialQueue:DispatchQueue, printLogs:Bool, namingF: @escaping NamingF, retainF: @escaping RetainF, keepTargetF: @escaping KeepTargetF, sortF: @escaping SortF) {
    self.baseDirectory = baseDirectory
    self.loggingQueue = serialQueue
    self.namingF = namingF
    self.retainF = retainF
    self.keepTargetF = keepTargetF
    self.sortF = sortF
    self.printLogs = printLogs
  }
  
  public func log(_ message:String) {
    
    loggingQueue.async {
      let now = Instant.now()
      
      let targetFile : OpenLogFile?
      if let openTarget = self.targetLogFile, self.keepTargetF(openTarget, now) {
        targetFile = openTarget
      } else if let newTarget = self.ensureLoggingTarget().value {
        targetFile = newTarget
      } else {
        targetFile = nil
      }
      
      if let openLogFile = targetFile {
        let string:String
        
        if let li = openLogFile.lastLoggedInstant, Instant.sameSecond(now, li) {
          string = " \(message)\n"
        } else {
          string = "@\(now.date) (\(now))\n \(message)\n"
          openLogFile.lastLoggedInstant = now
        }
        if self.printLogs { // && message.hasPrefix("AudioPlayer")
          print("\(string)", separator: "", terminator: "")
        }
        
        if let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false) {
          openLogFile.handle.write(data)
          openLogFile.handle.synchronizeFile()
        }
      }
    }
  }
  
  
  public func fence() -> Future<Bool, NoError> {
    return loggingQueue.asyncValue { true }
  }
  
  public func snapshot(gzip:Bool = false, size:UInt64 = 10000000) -> Future<Data, LoggingTargetFailure> {
    return loggingQueue.asyncResult { () -> Result<Data, LoggingTargetFailure> in
      self.ensureTargetClosed()
      let existingFiles = SimpleLog.logFilesIn(directory: self.baseDirectory)
      
      return existingFiles.flatMap { logFiles -> Result<Data, LoggingTargetFailure> in
        let sortedLogFiles = logFiles.sorted(by: self.sortF)
        
        var takeRemaining = size
        
        var startAt : (Int, Int) = (0, 0) // file #, data start
        
        let fileIndices = Array(sortedLogFiles.indices.reversed())
        
        for idx in fileIndices { // reverse
          let file = sortedLogFiles[idx]
          if takeRemaining < file.size {
            // partial cut
            startAt = (idx, Int(file.size - takeRemaining))
            takeRemaining = 0
            break
          } else {
            takeRemaining -= file.size
          }
        }
        
        let snapshotSize = Int(size - takeRemaining)
        
        var snapshotData = Data(capacity: snapshotSize)
        
        for i in (startAt.0)..<sortedLogFiles.count {
          let file = sortedLogFiles[i]
          
          if let handle = FileHandle(forReadingAtPath: file.path) {
            //              dLog("available data in file \(file) is  \(handle.availableData.length)")
            if i == startAt.0 {
              handle.seek(toFileOffset: UInt64(startAt.1))
            } else {
              handle.seek(toFileOffset: 0)
            }
            
            snapshotData.append(handle.readDataToEndOfFile())
            
            handle.closeFile()
          } else {
            return Result.failure(.CouldntOpenReadFileHandleForSnapshot(path:file.path))
          }
        }
        
        if gzip {
          let maybeZippedData = throwableToOption { try snapshotData.gzipped() }
          if let zippedData = maybeZippedData {
            return Result.success(zippedData)
          } else {
            return Result.failure(.CompressionFailure(inputDataLength: snapshotSize))
          }
        } else {
          return Result.success(snapshotData)
        }
      }
    }
  }
  
  public func shutdown() -> Future<(), LoggingTargetFailure> {
    return loggingQueue.asyncResult { _  in // () -> Result<(), LoggingTargetFailure>
      self.ensureTargetClosed()
      return Result.success(())
    }
  }
  
  private func ensureTargetClosed() {
    if let alreadyOpen = self.targetLogFile {
      alreadyOpen.handle.synchronizeFile()
      alreadyOpen.handle.closeFile()
      self.targetLogFile = nil
    }
  }
  
  private func ensureLoggingTarget() -> Result<OpenLogFile, LoggingTargetFailure> { // note: we might have none, or we might have
    ensureTargetClosed()
    
    let existingFiles = SimpleLog.logFilesIn(directory: self.baseDirectory)
    
    let fm = FileManager.default
    
    return existingFiles.flatMap { logFiles -> Result<OpenLogFile, LoggingTargetFailure> in
      let retained = Set(self.retainF(logFiles))
      
      let (toKeep, toDelete) = Collections.partition(logFiles) { lf in retained.contains(lf) }
      
      for logFile in toDelete {
        let deleteResult = throwableToResult { try fm.removeItem(atPath: logFile.path) }.mapError { error in LoggingTargetFailure.CouldNotDeleteUnretainedLogFile(logFile: logFile, error: error) }
        switch deleteResult {
        case .success(_): ()
        case .failure(let error): return Result.failure(error)
        }
      }
 
      let now = Instant.now()
      
      let newName = self.namingF(now, toKeep)
      let existingLogFile = toKeep.filter { lf in lf.name == newName }.first
      
      if let logFile = existingLogFile {
        // they wanted an existing log file
        let olf = OpenLogFile.openAt(path: logFile.path)
        self.targetLogFile = olf.value
        return olf
      } else {
        // it's new
        let fullPath = "\(self.baseDirectory)/\(newName)"
        let olf = OpenLogFile.openAt(path: fullPath)
        self.targetLogFile = olf.value
        return olf
      }
    }
  }
}

public enum LoggingTargetFailure : Error {
  case FailureFindingExistingFiles(error:NSError)
  case CouldNotDeleteUnretainedLogFile(logFile:LogFile, error:NSError)
  case CouldntOpenFileHandle(path:String)
  case CouldntWriteTo(path:String, error:NSError)
  case CouldntCreateLogFileDespiteSuccessfulWrite(path:String) // should never happen, but as a logger we still need to fail silently :-/
  case CouldntAllocateSnapshotData(size:Int)
  case CouldntOpenReadFileHandleForSnapshot(path:String)
  case CompressionFailure(inputDataLength:Int)
  case NoLogger // used as convenience down stream when you ask for a snapshot, but you dont actually have a logger :-/
}

public enum LoggerCreationFailure : Error {
  case CouldntCreateDirectory(path:String, error:NSError)
}

public struct SimpleLog {
  static func dLog(msg:String) {
    timedPrint("SimpleLog :: \(msg)")
  }
  
  static func millisecondDateFormatter() -> DateFormatter {
    let dateFormat = DateFormatter()
    dateFormat.dateFormat = "YYYY_MM_dd__HH_mm_ss.SSS"
    return dateFormat
  }
  
  public static func logFilesIn(directory:String) -> Result<[LogFile], LoggingTargetFailure> {
    return Files.filesIn(directory: directory).map { paths in
      return paths.flatMap { path in logFileFor(path: "\(directory)/\(path)") }
      }.mapError { error in LoggingTargetFailure.FailureFindingExistingFiles(error: error) }
  }
  
  public static func logFileFor(path:String) -> LogFile? {
    let maybeAttributes = throwableToOption { try FileManager.default.attributesOfItem(atPath: path) }
    if let attrib = maybeAttributes, let fileSize = attrib[FileAttributeKey.size] as? NSNumber, let modificationDate = attrib[FileAttributeKey.modificationDate] as? NSDate {
      return LogFile(path: path, size: fileSize.uint64Value, modifiedAt: modificationDate)
    } else {
      return nil
    }
  }
  
  public static func createLoggerSilently(f:() -> Result<Logger, LoggerCreationFailure>) -> Logger? {
    let result = f()
    
    switch result {
    case .success(let logger): return logger
    case .failure(let error):
      timedPrint("== Failure to create logger \(error)")
      //    dLog("=== Failure to create logger -> \(error) ===")
      return nil
    }
  }
  
  public static func createRollingWindowLogger(baseDirectory:String, queue:DispatchQueue, logCount:Int, logSize:UInt64, printLogs:Bool = false) -> Result<Logger, LoggerCreationFailure> {
    let dateFormat = millisecondDateFormatter()
    
    let sortF : SortF = { (logFileA, logFileB) in logFileA.path < logFileB.path }
    let namingF : NamingF = { (instant, logFiles) in
      if let mostRecentLogFile = logFiles.sorted(by: sortF).last, mostRecentLogFile.size < logSize {
        return mostRecentLogFile.name
      } else {
        let formattedDate = dateFormat.string(from: instant.date)
        return "\(formattedDate).log"
      }
    }
    let keepLastNLogs : RetainF = { arr in
      return Array(arr.sorted { (a, b) in a.path < b.path }.suffix(logCount))
    }
    let keepTargetUpToSize : KeepTargetF = { (openLogFile, data) in openLogFile.handle.offsetInFile < logSize }
    
    do {
      try FileManager.default.createDirectory(atPath: baseDirectory, withIntermediateDirectories: true, attributes: nil)
      
      return Result.success(
        Logger(
          baseDirectory:baseDirectory,
          serialQueue: queue,
          printLogs: printLogs,
          namingF: namingF,
          retainF: keepLastNLogs,
          keepTargetF: keepTargetUpToSize,
          sortF: sortF
        )
      )
    } catch let error as NSError {
      return Result.failure(LoggerCreationFailure.CouldntCreateDirectory(path: baseDirectory, error:error))
    }
  }
  
  // opens a new file each session, never deletes any logs
  public static func createUnboundedSessionLogger(baseDirectory:String, queue:DispatchQueue) -> Result<Logger, LoggerCreationFailure> {
    let dateFormat = millisecondDateFormatter()
    
    // this is the simplest method, it will spam a lot of logs and keep them all
    let sortF : SortF = { (logFileA, logFileB) in logFileA.path < logFileB.path }
    let secondNaming : NamingF = { (instant, logFiles) in
      let formattedDate = dateFormat.string(from: instant.date)
      return "\(formattedDate).log"
    }
    let keepAllLogs : RetainF = { arr in arr } // keep
    let alwaysKeepTarget : KeepTargetF = { (openLogFile, instant) in true }
    
    do {
      try FileManager.default.createDirectory(atPath: baseDirectory, withIntermediateDirectories: true, attributes: nil)
      
      return Result.success(
        Logger(
          baseDirectory:baseDirectory,
          serialQueue: queue,
          printLogs: false,
          namingF: secondNaming,
          retainF: keepAllLogs,
          keepTargetF: alwaysKeepTarget,
          sortF: sortF
        )
      )
    } catch let error as NSError {
      return Result.failure(LoggerCreationFailure.CouldntCreateDirectory(path: baseDirectory, error:error))
    }
  }
}
