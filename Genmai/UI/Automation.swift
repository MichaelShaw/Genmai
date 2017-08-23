//
//  Automation.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import BrightFutures
import Result

public typealias SpawnedPopup = Bool

public class Automation {
  public var animatingTransition:Bool = false
  let windowRootControllerF: (() -> UIViewController?)
  let spawnMessagesF: (UIViewController) -> Bool
  
  public init(windowRootControllerF: @escaping (() -> UIViewController?), spawnMessagesF: @escaping (UIViewController) -> Bool) {
    self.windowRootControllerF = windowRootControllerF
    self.spawnMessagesF = spawnMessagesF
  }
  
  public func startAnimating() {
    self.animatingTransition = true
  }
  
  public func stopAnimating() {
    self.animatingTransition = false
  }
  
  public func checkMessages() -> SpawnedPopup {
    if animatingTransition  { // we're not doing anything // || !TickTockApplication.sharedInstance.inForeground()
      return false
    }
    
    if let vc = visibleViewController() {
      return self.spawnMessagesF(vc) // unsure of what this does really
    } else {
      return false
    }
  }
  
  func windowRootController() -> UIViewController? {
    return self.windowRootControllerF()
  }
  
  public func visibleViewController() -> UIViewController? {
    if let rc = windowRootController() {
      return PathUtil.walkUp(viewController :rc).last
    } else {
      return nil
    }
  }
  
  public func present(presenter:UIViewController, presented: UIViewController, suppressPopup:Bool = false) -> Future<Bool, NoError> {
    let promise = Promise<Bool, NoError>()
    startAnimating()
    
    presenter.present(presented, animated: true) {
      self.stopAnimating()
      promise.success(true)
      if !suppressPopup {
        let _ = self.checkMessages()
      }
    }
    
    return promise.future
  }
  
  public func dismiss(viewController:UIViewController, skipMessages:Bool = false) -> Future<Bool, NoError> {
    let promise = Promise<Bool, NoError>()
    
    startAnimating()
    
    let presentingVC = viewController.presentingViewController!
    presentingVC.dismiss(animated: true) {
      self.stopAnimating()
      promise.success(true)
      if !skipMessages {
        let _ = self.checkMessages()
      }
    }
    return promise.future
  }
  
  public func dismissUnanimated(viewController:UIViewController, skipMessages:Bool = false) {
    let presentingVC = viewController.presentingViewController!
    presentingVC.dismiss(animated: false, completion: nil)
  }
  
  public func push(nav:UINavigationController, viewController: UIViewController, skipMessages:Bool = false) -> Future<(), NoError> {
    let promise = Promise<(), NoError>()
    startAnimating()
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      self.stopAnimating()
      promise.success(())
      if !skipMessages {
        let _ = self.checkMessages()
      }
    }
    nav.pushViewController(viewController, animated: true)
    CATransaction.commit()
    return promise.future
  }
  
  public func pop(nav: UINavigationController, viewController:UIViewController, skipMessages:Bool = false) -> Future<(), NoError> {
    let promise = Promise<(), NoError>()
    startAnimating()
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      self.stopAnimating()
      promise.success(())
      if !skipMessages {
        let _ = self.checkMessages()
      }
    }
    nav.popViewController(animated: true)
    CATransaction.commit()
    return promise.future
  }
  
  public func popUntilVisible(nav: UINavigationController, makeVisible:UIViewController, skipMessages:Bool = false) -> Future<(), NoError> {
    let promise = Promise<(), NoError>()
    startAnimating()
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      self.stopAnimating()
      promise.success(())
      if !skipMessages {
        let _ = self.checkMessages()
      }
    }
    nav.popToViewController(makeVisible, animated: true)
    CATransaction.commit()
    return promise.future
  }
}
