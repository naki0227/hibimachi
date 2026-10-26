import Foundation
import HibimachiCore

/// Player-facing names for what lives on the island (objects, reactions, residents).
extension ObjectKind {
    var displayName: String {
        switch self {
        case .roundTree: String(localized: "まるい木")
        case .pineTree: String(localized: "とがった木")
        case .house: String(localized: "小さな家")
        case .bench: String(localized: "ベンチ")
        case .flower: String(localized: "はなやぶ")
        case .pond: String(localized: "池")
        case .lamp: String(localized: "ランプ")
        case .sakuraTree: String(localized: "さくらの木")
        case .bush: String(localized: "しげみ")
        case .rock: String(localized: "いわ")
        case .fence: String(localized: "さく")
        case .mailbox: String(localized: "ポスト")
        case .picnicMat: String(localized: "ピクニックシート")
        case .birdhouse: String(localized: "巣箱")
        case .swing: String(localized: "ブランコ")
        case .campfire: String(localized: "たき火")
        case .well: String(localized: "井戸")
        case .garden: String(localized: "はたけ")
        case .fountain: String(localized: "ふんすい")
        case .cafe: String(localized: "カフェ")
        }
    }

    /// What unlocks a kind, for the palette ("Lv2 か 発見3").
    var unlockHint: String {
        let requirement = Unlocks.requirement(for: self)
        return String(localized: "Lv\(requirement.level) / 発見\(requirement.discoveries)")
    }
}

extension ReactionKind {
    var title: String {
        switch self {
        case .benchRest: String(localized: "ベンチでひと休み")
        case .bloomBench: String(localized: "花をながめて休む")
        case .treeNap: String(localized: "木かげでうたた寝")
        case .pondVisit: String(localized: "池をのぞきこむ")
        case .sakuraViewing: String(localized: "さくらを見上げる")
        case .swingPlay: String(localized: "ブランコでゆらゆら")
        case .campfireWarm: String(localized: "たき火でぬくぬく")
        case .gardenTend: String(localized: "はたけのお世話")
        case .fountainSplash: String(localized: "ふんすいで水あそび")
        case .cafeVisit: String(localized: "カフェにより道")
        case .cafeTerrace: String(localized: "テラスでひと息")
        case .picnic: String(localized: "木かげのピクニック")
        case .birdWatch: String(localized: "巣箱のバードウォッチ")
        case .mailWait: String(localized: "おてがみ待ち")
        case .wellPeek: String(localized: "井戸をのぞく")
        case .fireflies: String(localized: "ほたるの池")
        case .lampGlow: String(localized: "ランプのひかり")
        case .stargazing: String(localized: "星をながめる")
        case .campfireCircle: String(localized: "たき火をかこむ")
        case .morningWater: String(localized: "朝の水くみ")
        }
    }

    var detail: String {
        switch self {
        case .benchRest: String(localized: "近くにベンチがあると、腰かけてのんびりする。")
        case .bloomBench: String(localized: "花のとなりのベンチがお気に入り。いつもよりうれしそう。")
        case .treeNap: String(localized: "木のそばに来ると、ころんと横になって眠ってしまう。")
        case .pondVisit: String(localized: "池のふちで、水面をじっとのぞきこむ。")
        case .sakuraViewing: String(localized: "ひらひら落ちる花びらを、首をかしげて見上げる。")
        case .swingPlay: String(localized: "ブランコに乗って、ゆらゆら。ちょっと得意げ。")
        case .campfireWarm: String(localized: "火のそばにすわって、手をかざしてぬくぬく。")
        case .gardenTend: String(localized: "はたけの葉っぱを一枚ずつ、ていねいに見てまわる。")
        case .fountainSplash: String(localized: "ふんすいのしぶきに、ぴょんと飛びはねる。")
        case .cafeVisit: String(localized: "カフェの窓をのぞいて、いいにおいをかぐ。")
        case .cafeTerrace: String(localized: "カフェの前のベンチで、ひと息ついている。ベンチを置いたからこそ。")
        case .picnic: String(localized: "木かげのシートでおべんとう。日なただとやらないみたい。")
        case .birdWatch: String(localized: "木のそばの巣箱を、じっと見守る。")
        case .mailWait: String(localized: "ポストの前で、だれかからのおてがみを待っている。")
        case .wellPeek: String(localized: "井戸の中に向かって「おーい」。こだまが返ってくる。")
        case .fireflies: String(localized: "夜、花のそばの池に、ほたるがふわりと集まる。")
        case .lampGlow: String(localized: "花にかこまれたランプのまわりを、小さなひかりが舞う。夜だけの景色。")
        case .stargazing: String(localized: "木のない空の下、シートに寝ころんで星をかぞえる。")
        case .campfireCircle: String(localized: "夕方から夜、たき火のそばのベンチで、ぱちぱちという音を聞いている。")
        case .morningWater: String(localized: "朝いちばんに、井戸で水をくむ。ひんやり気持ちいい。")
        }
    }

    /// Short emote shown above the resident while reacting.
    var emote: String {
        switch self {
        case .benchRest, .swingPlay: "♪"
        case .bloomBench: "✿♪"
        case .treeNap, .campfireWarm: "z z"
        case .pondVisit, .birdWatch: "…"
        case .sakuraViewing: "✿"
        case .gardenTend: "♣"
        case .fountainSplash: "!"
        case .cafeVisit, .cafeTerrace: "☕"
        case .picnic: "♪♪"
        case .mailWait: "?"
        case .wellPeek: String(localized: "おーい")
        case .fireflies, .lampGlow: "✧"
        case .stargazing: "☆"
        case .campfireCircle: "♪"
        case .morningWater: "～"
        }
    }

    /// Reactions drawn with closed eyes.
    var looksSleepy: Bool { self == .treeNap || self == .bloomBench || self == .campfireWarm }
}

extension Species {
    var displayName: String {
        switch self {
        case .mochi: String(localized: "もち")
        case .kotori: String(localized: "ことり")
        case .tanuki: String(localized: "こだぬき")
        }
    }

    /// One line for the arrival card.
    var arrivalLine: String {
        switch self {
        case .mochi: String(localized: "島のさいしょの住人です。")
        case .kotori: String(localized: "木や巣箱、水のあるところが好きみたい。")
        case .tanuki: String(localized: "たき火やはたけ、ピクニックが好きみたい。")
        }
    }
}

extension ReactionKind {
    /// A soft hint that points at a reaction without spelling it out (shown after finishing a quest).
    var hint: String {
        switch self {
        case .benchRest: String(localized: "ベンチのまわりをあけておくと、だれかが座りにくるかも")
        case .bloomBench: String(localized: "ベンチのとなりに花があったら…？")
        case .treeNap: String(localized: "木のそばは、ひなたぼっこにちょうどよさそう")
        case .pondVisit: String(localized: "池のまわりを歩きやすくしてみたら…？")
        case .sakuraViewing: String(localized: "さくらの木の下で、だれかが上を見ているかも")
        case .swingPlay: String(localized: "ブランコ、だれか乗りにこないかな")
        case .campfireWarm: String(localized: "たき火のそばは、あたたかそう")
        case .gardenTend: String(localized: "はたけの葉っぱ、だれか気にしているみたい")
        case .fountainSplash: String(localized: "ふんすいのしぶき、気になる子がいるかも")
        case .cafeVisit: String(localized: "カフェから、いいにおいがしてきそう")
        case .cafeTerrace: String(localized: "カフェの前に、すわれる場所があったら…？")
        case .picnic: String(localized: "ピクニックシートは、日なたより木かげが好きみたい")
        case .birdWatch: String(localized: "巣箱は、木のそばにあると落ち着くみたい")
        case .mailWait: String(localized: "ポストの前で、だれかが待っているかも")
        case .wellPeek: String(localized: "井戸の中から、何か聞こえるかも")
        case .fireflies: String(localized: "夜の池のそばに花があったら…？")
        case .lampGlow: String(localized: "夜、花にかこまれたランプには何かが集まるかも")
        case .stargazing: String(localized: "夜、木のないところにシートを広げてみたら…？")
        case .campfireCircle: String(localized: "たき火のそばにベンチがあったら、夜が楽しそう")
        case .morningWater: String(localized: "朝の井戸に、だれかが来るかも")
        }
    }
}

extension NextStep {
    var message: String {
        switch self {
        case .canBuild(let kind): String(localized: "\(kind.displayName)を置いてみると、だれかが寄ってくるかも")
        case .tryReaction(let reaction): reaction.hint
        case .unlocksSoon(let kind, let requirement):
            String(localized: "Lv\(requirement.level)か、発見\(requirement.discoveries)つで\(kind.displayName)が置けるように")
        }
    }

    var symbolName: String {
        switch self {
        case .canBuild: "hammer.fill"
        case .tryReaction: "sparkle.magnifyingglass"
        case .unlocksSoon: "lock.open.fill"
        }
    }
}
