//
//  View+Snapshot.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/6/1.
//

import Foundation
import SwiftUI

extension View {
    private func snapshotSingle() -> UIImage {
        let controller = UIHostingController(rootView: self, ignoreSafeArea: true)
        if let view = controller.view {
            let targetSize = view.intrinsicContentSize
            view.bounds = CGRect(origin: .zero, size: targetSize)
            view.backgroundColor = .clear

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { context in
                view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
        }

        return UIImage()
    }

    func snapshot() -> UIImage {
        let image = snapshotSingle()
        image.imageAsset?.register(environment(\.colorScheme, .dark).snapshotSingle(), with: .init(userInterfaceStyle: .dark))
        return image
    }
}
