//
//  PathUtil.swift
//  Genmai
//
//  Created by Michael Shaw on 23/8/17.
//  Copyright © 2017 Cosmic Teapot. All rights reserved.
//

import UIKit

public struct PathUtil {
  public static func printSubviews(v:UIView, spaces:Int = 0, depth:Int = 2) {
    if depth == 0 {
      return
    }
    let padding = String(repeating: " ", count: spaces)
    
    print("\(padding)-> \(type(of: v)) (autoresize: \(v.translatesAutoresizingMaskIntoConstraints)) \(v.frame)")
    
    for sv in v.subviews {
      printSubviews(v: sv, spaces: spaces + 2, depth: depth - 1)
    }
  }
  
  public static func walkDownVisible(viewController vc:UIViewController, thusFar: [UIViewController] = []) -> [UIViewController] {
    let withMe : [UIViewController] = [vc] + thusFar
    
    if let nvc = vc.navigationController {
      var fromNav : [UIViewController] = []
      for snvc in nvc.viewControllers {
        if snvc == vc { // found self
          break
        } else {
          fromNav.append(snvc)
        }
      }
      return walkDownVisible(viewController: nvc, thusFar: fromNav + withMe)
    } else if let tvc = vc.tabBarController {
      return walkDownVisible(viewController: tvc, thusFar: withMe)
    } else if let pvc = vc.presentingViewController {
      return walkDownVisible(viewController: pvc, thusFar: withMe)
    } else {
      return withMe
    }
  }
  
  public static func walkUp(viewController vc:UIViewController, thusFar:[UIViewController] = []) -> [UIViewController] {
    let withMe : [UIViewController] = thusFar + [vc]
    
    if let nvc = vc as? UINavigationController, let lvc = nvc.viewControllers.last {
      return walkUp(viewController: lvc, thusFar: withMe + Array(nvc.viewControllers.dropLast()))
    } else if let tc = vc as? UITabBarController, let svc = tc.selectedViewController {
      return walkUp(viewController: svc, thusFar: withMe)
    } else if let pvc = vc.presentedViewController { // last resort to jump the shark
      return walkUp(viewController: pvc, thusFar: withMe)
    } else if let nav = vc.navigationController, let idx = nav.viewControllers.index(of: vc), idx < nav.viewControllers.count - 1, let lvc = nav.viewControllers.last {
      // if we are not the top VC within a nav ... take the top and walk down from it (in theory it will be the last)
      return walkUp(viewController: lvc, thusFar: withMe)
    } else {
      return withMe
    }
  }
  
  public static func walkUp(view:UIView, thusFar:[UIView] = []) -> [UIView] {
    var path : [UIView] = [view]
    var current = view
    
    while let sv = current.superview {
      path.append(sv)
      current = sv
    }
    
    path.reverse()
    
    return path
  }
}
