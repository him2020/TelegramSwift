//
//  InputSources.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import SwiftSignalKit
import Foundation
import TelegramCore
import SyncCore
import Postbox


final class InputSources: NSObject {
    
    private let _inputSource: ValuePromise<[String]> = ValuePromise(["en"], ignoreRepeated: true)
    
    var value: Signal<[String], NoError> {
        _inputSource.set(currentAppInputSource().uniqueElements)
        return _inputSource.get() |> distinctUntilChanged(isEqual: { $0 == $1 })
    }
    
    func searchEmoji(postbox: Postbox, sharedContext: SharedAccountContext, query: String, completeMatch: Bool, checkPrediction: Bool) -> Signal<[String], NoError> {
        return combineLatest(value, baseAppSettings(accountManager: sharedContext.accountManager)) |> mapToSignal { sources, settings in
            if settings.predictEmoji || !checkPrediction {
                return combineLatest(sources.map({ searchEmojiKeywords(postbox: postbox, inputLanguageCode: $0, query: query.lowercased(), completeMatch: completeMatch) })) |> map { results in
                    return results.reduce([], { $0 + $1 }).reduce([], { current, value -> [String] in
                        if completeMatch {
                            if query.lowercased() == value.keyword.lowercased() {
                                return current + value.emoticons
                            } else {
                                return current
                            }
                        } else {
                            return current + value.emoticons
                        }
                    }).uniqueElements.map { $0.fixed }
                } |> distinctUntilChanged
            } else {
                return .single([])
            }
        }
    }
    
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(inputSourceChanged), name: NSTextInputContext.keyboardSelectionDidChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func inputSourceChanged() {
       _inputSource.set(currentAppInputSource().uniqueElements)
    }
}
