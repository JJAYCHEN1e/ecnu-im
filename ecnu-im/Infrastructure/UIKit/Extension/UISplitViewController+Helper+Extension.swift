//
//  UISplitViewController+Helper+Extension.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/4/3.
//

import Foundation
import SwiftUI
import UIKit

extension UISplitViewController {
    var primaryNVC: UINavigationController? {
        if let primaryNVC = viewController(for: .primary) as? UINavigationController {
            return primaryNVC
        }
        return nil
    }

    var secondaryNVC: UINavigationController? {
        if let secondaryNVC = viewController(for: .secondary) as? UINavigationController {
            return secondaryNVC
        }
        return nil
    }

    func push(viewController: UIViewController, column: UISplitViewController.Column, animated: Bool = false, toRoot: Bool = false) {
        if let nvc = self.viewController(for: column) as? UINavigationController {
            if let noOverlayVC = viewController as? NoOverlayViewController {
                guard noOverlayVC.shouldPushTo(nvc: nvc) else { return }
            }

            if viewController.navigationItem.scrollEdgeAppearance == nil {
                viewController.navigationItem.scrollEdgeAppearance = UINavigationBarAppearance()
            }

            if traitCollection.horizontalSizeClass == .compact {
                if secondaryNVC == nvc,
                   nvc.viewControllers.count == 0,
                   primaryNVC?.topViewController !== nvc {
                    // nvc.viewControllers.count == 0 only when in compact mode, secondary column
                    nvc.viewControllers = [viewController]
                    primaryNVC?.pushViewController(nvc, animated: true)
                    return
                }
            }

            var animated = animated
            if toRoot {
                animated = false
            }

            if nvc === secondaryNVC, nvc.viewControllers.count == 1 {
                animated = false
            }

            if animated {
                nvc.pushViewController(viewController, animated: animated)
            } else {
                nvc.viewControllers = nvc.viewControllers + [viewController]
            }
        }
    }

    func pop(from nvc: UINavigationController, animated: Bool = false) {
        if nvc === primaryNVC {
            nvc.popViewController(animated: animated)
        } else if nvc === secondaryNVC {
            if traitCollection.horizontalSizeClass == .compact,
               nvc.viewControllers.count == 1,
               let primaryNVC = primaryNVC {
                // only when in compact mode, since there is no empty view placeholder
                primaryNVC.popViewController(animated: animated)
                nvc.viewControllers = []
                return
            }

            nvc.popViewController(animated: animated)
        }
    }
}
