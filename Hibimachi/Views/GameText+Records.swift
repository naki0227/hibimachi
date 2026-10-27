import Foundation
import HibimachiCore
import SwiftUI

/// Copy for task sessions and records (ADR-0015).
extension RecordStyle {
    /// Shown when the quest starts.
    var startHint: String {
        switch self {
        case .beforeAfter: String(localized: "どこを片付ける？ まえを撮っておくと、あとでくらべられます。")
        case .result: String(localized: "できたら、できたものを撮って残せます。")
        case .amount: String(localized: "やっているところを撮ってもOK。終わったら、どれくらいやったかを残せます。")
        case .feeling: String(localized: "ゆっくりしたら、どんな気分だったかを残せます。")
        }
    }

    var notePlaceholder: LocalizedStringKey {
        switch self {
        case .beforeAfter: LocalizedStringKey("どこを片付けた？（なくてもOK）")
        case .feeling: LocalizedStringKey("どんな気分？（なくてもOK）")
        case .result, .amount: LocalizedStringKey("ひとこと（なくてもOK）")
        }
    }

    /// What makes the record complete (and earns the small bonus), without needing a camera.
    var completeHint: String {
        switch self {
        case .beforeAfter: String(localized: "まえとあとの写真、またはひとことで記録がそろいます")
        case .result: String(localized: "写真か、ひとことで記録がそろいます")
        case .amount: String(localized: "やった量を入れると記録がそろいます")
        case .feeling: String(localized: "ひとことで記録がそろいます")
        }
    }
}

extension AmountUnit {
    var title: String {
        switch self {
        case .minutes: String(localized: "分")
        case .times: String(localized: "回")
        case .pages: String(localized: "ページ")
        case .items: String(localized: "問")
        }
    }
}

extension TaskAmount {
    /// "20回" / "20 times".
    var text: String {
        switch unit {
        case .minutes: String(localized: "\(value)分")
        case .times: String(localized: "\(value)回")
        case .pages: String(localized: "\(value)ページ")
        case .items: String(localized: "\(value)問")
        }
    }
}
