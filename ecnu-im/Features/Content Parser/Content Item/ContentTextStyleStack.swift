//
//  ContentTextStyleStack.swift
//  ecnu-im
//
//  Created by 陈俊杰 on 2022/4/25.
//

import Foundation
import UIKit

enum ContentTextStyle {
    case fontSize(CGFloat)
    case textColor(UIColor)
    case bold
    case mono
    case italic
    case underline
    case strikethrough
    case `subscript`
    case superscript
    case markerColor(UIColor)
    case link(String)
    case lineSpacing(CGFloat)
}

let ContentMarkerColorAttribute = "MarkerColorAttribute"

final class ContentTextStyleStack {
    private var items: [ContentTextStyle] = []

    init() {}

    init(items: [ContentTextStyle]) {
        self.items = items
    }

    func push(_ item: ContentTextStyle) {
        items.append(item)
    }

    func pop() {
        if !items.isEmpty {
            items.removeLast()
        }
    }

    func textAttributes() -> [NSAttributedString.Key: Any] {
        var fontSize: CGFloat?
        var textColor: UIColor?
        var bold: Bool?
        var mono: Bool?
        var italic: Bool?
        var strikethrough: Bool?
        var underline: Bool?
        var baselineOffset: CGFloat?
        var markerColor: UIColor?
        var link: String?
        var lineSpacing: CGFloat?

        for item in items.reversed() {
            switch item {
            case let .fontSize(value):
                if fontSize == nil {
                    fontSize = value
                }
            case let .textColor(value):
                if textColor == nil {
                    textColor = value
                }
            case .bold:
                if bold == nil {
                    bold = true
                }
            case .mono:
                if mono == nil {
                    mono = true
                }
            case .italic:
                if italic == nil {
                    italic = true
                }
            case .strikethrough:
                if strikethrough == nil {
                    strikethrough = true
                }
            case .underline:
                if underline == nil {
                    underline = true
                }
            case .subscript:
                if baselineOffset == nil {
                    baselineOffset = 0.35
                    underline = false
                }
            case .superscript:
                if baselineOffset == nil {
                    baselineOffset = -0.35
                }
            case let .markerColor(color):
                if markerColor == nil {
                    markerColor = color
                }
            case let .link(url):
                if link == nil {
                    link = url
                }
                if textColor == nil {
                    textColor = .systemTeal
                }
                if underline == nil {
                    underline = true
                }
            case let .lineSpacing(_lineSpacing):
                if lineSpacing == nil {
                    lineSpacing = _lineSpacing
                }
            }
        }

        var attributes: [NSAttributedString.Key: Any] = [:]

        var parsedFontSize: CGFloat
        if let fontSize = fontSize {
            parsedFontSize = fontSize
        } else {
            parsedFontSize = 16.0
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = parsedFontSize * (lineSpacing ?? 1.4 - 1)
        attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle

        if let baselineOffset = baselineOffset {
            attributes[NSAttributedString.Key.baselineOffset] = round(parsedFontSize * baselineOffset)
            parsedFontSize = round(parsedFontSize * 0.85)
        }

        if link != nil {
            attributes[NSAttributedString.Key.font] = Font.medium(parsedFontSize)
        } else if mono != nil, mono!, bold != nil, bold!, italic != nil, italic! {
            attributes[NSAttributedString.Key.font] = Font.semiboldItalicMonospace(parsedFontSize)
        } else if mono != nil, mono!, italic != nil, italic! {
            attributes[NSAttributedString.Key.font] = Font.italicMonospace(parsedFontSize)
        } else if mono != nil, mono!, bold != nil, bold! {
            attributes[NSAttributedString.Key.font] = Font.semiboldMonospace(parsedFontSize)
        } else if bold != nil, bold!, italic != nil, italic! {
            attributes[NSAttributedString.Key.font] = Font.semiboldItalic(parsedFontSize)
        } else if bold != nil, bold! {
            attributes[NSAttributedString.Key.font] = Font.bold(parsedFontSize)
        } else if italic != nil, italic! {
            attributes[NSAttributedString.Key.font] = Font.italic(parsedFontSize)
        } else if mono != nil, mono! {
            attributes[NSAttributedString.Key.font] = Font.monospace(parsedFontSize)
        } else {
            attributes[NSAttributedString.Key.font] = Font.regular(parsedFontSize)
        }

        if strikethrough != nil, strikethrough! {
            attributes[NSAttributedString.Key.strikethroughStyle] = NSUnderlineStyle.single.rawValue as NSNumber
        }

        if underline != nil, underline! {
            if link != nil {
                attributes[NSAttributedString.Key.underlineStyle] = NSUnderlineStyle.single.rawValue
                attributes[NSAttributedString.Key.underlineColor] = UIColor.gray.withAlphaComponent(0.5)
            } else {
                attributes[NSAttributedString.Key.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
        }

        if let textColor = textColor {
            attributes[NSAttributedString.Key.foregroundColor] = textColor
        } else {
            attributes[NSAttributedString.Key.foregroundColor] = Asset.DynamicColors.dynamicBlack.color
        }

        if let link = link {
            attributes[NSAttributedString.Key.link] = link
        }

        if let markerColor = markerColor {
//            attributes[NSAttributedString.Key(rawValue: ContentMarkerColorAttribute)] = markerColor
            attributes[NSAttributedString.Key.backgroundColor] = markerColor
        }

        return attributes
    }
}
