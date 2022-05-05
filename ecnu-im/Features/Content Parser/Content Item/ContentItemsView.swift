//
//  ContentItemsView.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/4/28.
//

import SwiftUI

struct PostContentItemsView: View {
    @Binding var contentItems: [Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(zip(contentItems.indices, contentItems)), id: \.0) { _, item in
                if let item = item as? ContentItemParagraph {
                    item
                }
                if let item = item as? ContentItemBlockquote {
                    item
                }
                if let item = item as? ContentItemDivider {
                    item
                }
                if let item = item as? LinkPreviewView {
                    item
                }
                if let item = item as? ContentItemSingleImage {
                    item
                }
                if let item = item as? ContentItemImagesGrid {
                    item
                }
                if let item = item as? ContentItemCodeBlock {
                    item
                }
            }
        }
    }
}

// struct PostContentView: View {
//    @State var content: String
//    @State var contentItems: [Any] = []
//
//    init(content: String) {
//        self.content = content
//    }
//
//    var body: some View {
//        PostContentItemsView(contentItems: $contentItems)
//            .onLoad {
//                let parseConfiguration = ParseConfiguration(imageOnTapAction: { ImageBrowser.shared.present(imageURLs: $1, selectedImageIndex: $0) },
//                                                            imageGridDisplayMode: .narrow)
//                let contentParser = ContentParser(content: content, configuration: parseConfiguration)
//                let newContentItems = contentParser.parse()
//                contentItems = newContentItems
//            }
//    }
// }

class PostContentItemsUIView: UIView {
    private var views: [UIView]

    init(contentItems: [UIView]) {
        views = contentItems
        super.init(frame: .zero)

        for view in views {
            addSubview(view)
        }
    }

    private let margin: CGFloat = 10.0
    private var totalHeight: CGFloat = 0.0

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard size.width > 0 else { return .zero }
        var totalHeight = 0.0
        for view in views {
            let size = view.sizeThatFits(.init(width: size.width, height: .infinity))
            totalHeight += size.height + margin
        }
        totalHeight -= margin
        self.totalHeight = totalHeight
        return CGSize(width: size.width, height: totalHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        var totalHeight = 0.0
        for view in views {
            let size = view.sizeThatFits(.init(width: bounds.width, height: .infinity))
            let frame = CGRect(origin: .init(x: (bounds.width - size.width) / 2.0, y: totalHeight), size: size)
            view.frame = frame
            totalHeight += size.height + margin
        }
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        return .zero
    }

    override var intrinsicContentSize: CGSize {
        return .init(width: bounds.width, height: totalHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
