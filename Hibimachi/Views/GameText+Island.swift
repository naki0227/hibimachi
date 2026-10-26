import HibimachiCore

/// Player-facing names for what lives on the island (objects, reactions, residents).
extension ObjectKind {
    var displayName: String {
        switch self {
        case .roundTree: "まるい木"
        case .pineTree: "とがった木"
        case .house: "小さな家"
        case .bench: "ベンチ"
        case .flower: "はなやぶ"
        case .pond: "池"
        case .lamp: "ランプ"
        case .sakuraTree: "さくらの木"
        case .bush: "しげみ"
        case .rock: "いわ"
        case .fence: "さく"
        case .mailbox: "ポスト"
        case .picnicMat: "ピクニックシート"
        case .birdhouse: "巣箱"
        case .swing: "ブランコ"
        case .campfire: "たき火"
        case .well: "井戸"
        case .garden: "はたけ"
        case .fountain: "ふんすい"
        case .cafe: "カフェ"
        }
    }

    /// What unlocks a kind, for the palette ("Lv2 か 発見3").
    var unlockHint: String {
        let requirement = Unlocks.requirement(for: self)
        return "Lv\(requirement.level) / 発見\(requirement.discoveries)"
    }
}

extension ReactionKind {
    var title: String {
        switch self {
        case .benchRest: "ベンチでひと休み"
        case .bloomBench: "花をながめて休む"
        case .treeNap: "木かげでうたた寝"
        case .pondVisit: "池をのぞきこむ"
        case .sakuraViewing: "さくらを見上げる"
        case .swingPlay: "ブランコでゆらゆら"
        case .campfireWarm: "たき火でぬくぬく"
        case .gardenTend: "はたけのお世話"
        case .fountainSplash: "ふんすいで水あそび"
        case .cafeVisit: "カフェにより道"
        case .cafeTerrace: "テラスでひと息"
        case .picnic: "木かげのピクニック"
        case .birdWatch: "巣箱のバードウォッチ"
        case .mailWait: "おてがみ待ち"
        case .wellPeek: "井戸をのぞく"
        }
    }

    var detail: String {
        switch self {
        case .benchRest: "近くにベンチがあると、腰かけてのんびりする。"
        case .bloomBench: "花のとなりのベンチがお気に入り。いつもよりうれしそう。"
        case .treeNap: "木のそばに来ると、ころんと横になって眠ってしまう。"
        case .pondVisit: "池のふちで、水面をじっとのぞきこむ。"
        case .sakuraViewing: "ひらひら落ちる花びらを、首をかしげて見上げる。"
        case .swingPlay: "ブランコに乗って、ゆらゆら。ちょっと得意げ。"
        case .campfireWarm: "火のそばにすわって、手をかざしてぬくぬく。"
        case .gardenTend: "はたけの葉っぱを一枚ずつ、ていねいに見てまわる。"
        case .fountainSplash: "ふんすいのしぶきに、ぴょんと飛びはねる。"
        case .cafeVisit: "カフェの窓をのぞいて、いいにおいをかぐ。"
        case .cafeTerrace: "カフェの前のベンチで、ひと息ついている。ベンチを置いたからこそ。"
        case .picnic: "木かげのシートでおべんとう。日なただとやらないみたい。"
        case .birdWatch: "木のそばの巣箱を、じっと見守る。"
        case .mailWait: "ポストの前で、だれかからのおてがみを待っている。"
        case .wellPeek: "井戸の中に向かって「おーい」。こだまが返ってくる。"
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
        case .wellPeek: "おーい"
        }
    }

    /// Reactions drawn with closed eyes.
    var looksSleepy: Bool { self == .treeNap || self == .bloomBench || self == .campfireWarm }
}

extension Species {
    var displayName: String {
        switch self {
        case .mochi: "もち"
        case .kotori: "ことり"
        case .tanuki: "こだぬき"
        }
    }

    /// One line for the arrival card.
    var arrivalLine: String {
        switch self {
        case .mochi: "島のさいしょの住人です。"
        case .kotori: "木や巣箱、水のあるところが好きみたい。"
        case .tanuki: "たき火やはたけ、ピクニックが好きみたい。"
        }
    }
}

extension ReactionKind {
    /// A soft hint that points at a reaction without spelling it out (shown after finishing a quest).
    var hint: String {
        switch self {
        case .benchRest: "ベンチのまわりをあけておくと、だれかが座りにくるかも"
        case .bloomBench: "ベンチのとなりに花があったら…？"
        case .treeNap: "木のそばは、ひなたぼっこにちょうどよさそう"
        case .pondVisit: "池のまわりを歩きやすくしてみたら…？"
        case .sakuraViewing: "さくらの木の下で、だれかが上を見ているかも"
        case .swingPlay: "ブランコ、だれか乗りにこないかな"
        case .campfireWarm: "たき火のそばは、あたたかそう"
        case .gardenTend: "はたけの葉っぱ、だれか気にしているみたい"
        case .fountainSplash: "ふんすいのしぶき、気になる子がいるかも"
        case .cafeVisit: "カフェから、いいにおいがしてきそう"
        case .cafeTerrace: "カフェの前に、すわれる場所があったら…？"
        case .picnic: "ピクニックシートは、日なたより木かげが好きみたい"
        case .birdWatch: "巣箱は、木のそばにあると落ち着くみたい"
        case .mailWait: "ポストの前で、だれかが待っているかも"
        case .wellPeek: "井戸の中から、何か聞こえるかも"
        }
    }
}

extension NextStep {
    var message: String {
        switch self {
        case .canBuild(let kind): "\(kind.displayName)を置いてみると、だれかが寄ってくるかも"
        case .tryReaction(let reaction): reaction.hint
        case .unlocksSoon(let kind, let requirement):
            "Lv\(requirement.level)か、発見\(requirement.discoveries)つで\(kind.displayName)が置けるように"
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
