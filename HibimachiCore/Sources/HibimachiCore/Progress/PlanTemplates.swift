import Foundation

/// Rule-based breakdowns per category (ADR-0016): used when on-device AI is off, unavailable or unreadable.
/// Three steps that grow from a small corner to the whole thing; targets are rough guides (7, 14, 21 times).
extension PlanDraft {
    public static func template(for category: GoalCategory, language: QuestPresets.Language = .japanese)
        -> PlanDraft
    {
        let rows = language == .english ? englishRows(category) : japaneseRows(category)
        return PlanDraft(
            steps: rows.map { row in
                Step(
                    title: row.title, target: row.target,
                    quests: row.quests.map { Quest(title: $0.0, minutes: $0.1) })
            })
    }

    private typealias Row = (title: String, target: Int, quests: [(String, Int)])

    private static func japaneseRows(_ category: GoalCategory) -> [Row] {
        switch category {
        case .tidy:
            [
                ("机まわりを整える", 7, [("机の上を5分だけ片付ける", 5), ("出しっぱなしを3つ戻す", 5)]),
                ("よく使う場所を整える", 14, [("引き出しを1段整理する", 10), ("いらない物を1つ手放す", 5)]),
                ("部屋全体をととのえる", 21, [("床の物を片付ける", 10), ("10分だけ掃除する", 10)]),
            ]
        case .study:
            [
                ("毎日ふれる習慣をつくる", 7, [("教科書を2ページ読む", 10), ("単語を5つ覚える", 10)]),
                ("基礎を固める", 14, [("昨日のノートを見返す", 5), ("問題を3つ解く", 15)]),
                ("できることを広げる", 21, [("間違えた問題を解き直す", 10), ("覚えたことを人に説明するつもりで書く", 10)]),
            ]
        case .rest:
            [
                ("ひと息つく時間をつくる", 7, [("深呼吸を10回する", 5), ("水を一杯ゆっくり飲む", 5)]),
                ("休み方を見つける", 14, [("5分だけ目を閉じて休む", 5), ("好きな音楽を1曲聴く", 5)]),
                ("休むのを習慣にする", 21, [("寝る前に画面を見ない時間をつくる", 15), ("散歩してひと休みする", 15)]),
            ]
        case .create:
            [
                ("作る時間を持つ", 7, [("アイデアを3つメモする", 5), ("10分だけ作品に触る", 10)]),
                ("ひとつ形にする", 14, [("下書き・ラフを進める", 15), ("好きな作品を1つ眺める", 5)]),
                ("仕上げて見せる", 21, [("仕上げを10分進める", 10), ("できたものを記録に残す", 5)]),
            ]
        case .move:
            [
                ("体を動かすきっかけをつくる", 7, [("ストレッチを5分する", 5), ("階段を使ってみる", 5)]),
                ("動く時間を増やす", 14, [("10分歩く", 10), ("スクワットを10回する", 5)]),
                ("続けられる運動にする", 21, [("20分体を動かす", 20), ("外の空気を吸いに出る", 10)]),
            ]
        case .other:
            [
                ("まず取りかかる", 7, [("5分だけ取りかかる", 5), ("次の一歩を1行メモする", 5)]),
                ("少しずつ進める", 14, [("10分だけ続きをやる", 10), ("できたことを1行書く", 5)]),
                ("形にする", 21, [("15分まとめて進める", 15), ("ふり返って次を決める", 5)]),
            ]
        }
    }

    private static func englishRows(_ category: GoalCategory) -> [Row] {
        switch category {
        case .tidy:
            [
                ("Tidy the desk area", 7, [("Clear the desk for 5 minutes", 5), ("Put 3 things back in place", 5)]),
                ("Sort the places you use most", 14, [("Sort one drawer", 10), ("Let go of one thing", 5)]),
                ("Tidy the whole room", 21, [("Pick things up off the floor", 10), ("Clean for 10 minutes", 10)]),
            ]
        case .study:
            [
                ("Touch it every day", 7, [("Read 2 pages of a textbook", 10), ("Learn 5 new words", 10)]),
                ("Build the basics", 14, [("Look over yesterday's notes", 5), ("Solve 3 problems", 15)]),
                ("Go further", 21, [("Redo a problem you missed", 10), ("Explain it as if teaching", 10)]),
            ]
        case .rest:
            [
                ("Make room to breathe", 7, [("Take 10 slow breaths", 5), ("Drink a glass of water slowly", 5)]),
                ("Find how you rest", 14, [("Close your eyes for 5 minutes", 5), ("Listen to one song you love", 5)]),
                ("Make rest a habit", 21, [("No screens before bed", 15), ("Take a restful walk", 15)]),
            ]
        case .create:
            [
                ("Make time to create", 7, [("Jot down 3 ideas", 5), ("Create for 10 minutes", 10)]),
                ("Give one thing a shape", 14, [("Work on a draft or sketch", 15), ("Enjoy one work you love", 5)]),
                ("Finish and show it", 21, [("Polish for 10 minutes", 10), ("Keep a record of what you made", 5)]),
            ]
        case .move:
            [
                ("Start moving", 7, [("Stretch for 5 minutes", 5), ("Take the stairs", 5)]),
                ("Move more", 14, [("Walk for 10 minutes", 10), ("Do 10 squats", 5)]),
                ("Make it a habit", 21, [("Move for 20 minutes", 20), ("Step outside for fresh air", 10)]),
            ]
        case .other:
            [
                ("Get started", 7, [("Start it for just 5 minutes", 5), ("Write down the next step", 5)]),
                (
                    "Keep going little by little", 14,
                    [("Keep going for 10 minutes", 10), ("Write one line on what you did", 5)]
                ),
                ("Give it a shape", 21, [("Work 15 minutes in one go", 15), ("Look back and pick what's next", 5)]),
            ]
        }
    }
}
