import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// A short, kind comment from Apple Intelligence on the device (iOS 26+, supported devices, turned on).
/// Returns `nil` whenever it cannot answer, so the caller falls back to the rule-based line.
enum AppleIntelligenceCoach {
    /// Generation stops after this; a slow first load should not keep the card waiting.
    static let timeout: Duration = .seconds(8)

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    static func comment(prompt: String, english: Bool) async -> String? {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                guard SystemLanguageModel.default.isAvailable else { return nil }
                let instructions = english ? englishInstructions : japaneseInstructions
                return await withTaskGroup(of: String?.self) { group in
                    group.addTask {
                        let session = LanguageModelSession(instructions: instructions)
                        return try? await session.respond(to: prompt).content
                    }
                    group.addTask {
                        try? await Task.sleep(for: timeout)
                        return nil
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
            }
        #endif
        return nil
    }

    static let japaneseInstructions = """
        あなたは箱庭ゲーム「ひびまち」に住む、やさしい生き物です。
        プレイヤーが現実でやったことの記録を読んで、ひとことだけ返します。
        ・日本語で1文、40文字以内。
        ・ほめる、ねぎらう、気づいたことを言う。点数や評価はつけない。
        ・本当にやったか、どれだけ上手かを決めつけない。命令や説教をしない。
        ・記録に書かれていないことを作らない。
        """

    static let englishInstructions = """
        You are a gentle creature living in the island game Hibimachi.
        Read the record of something the player did in real life and reply with one short sentence.
        - English, one sentence, at most 15 words.
        - Praise, thank or notice something. No scores or grades.
        - Never judge whether it really happened or how well it was done. No orders or lectures.
        - Do not invent anything that is not in the record.
        """
}
