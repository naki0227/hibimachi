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
        await respond(to: prompt, instructions: english ? englishInstructions : japaneseInstructions, timeout: timeout)
    }

    /// One answer from the on-device model, or `nil` (unavailable, failed or slower than `timeout`).
    /// Whichever finishes first wins; a task group would wait for a model call that ignores cancellation.
    static func respond(to prompt: String, instructions: String, timeout: Duration) async -> String? {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                guard SystemLanguageModel.default.isAvailable else { return nil }
                return await withCheckedContinuation { continuation in
                    let gate = FirstAnswer(continuation)
                    let work = Task {
                        let session = LanguageModelSession(instructions: instructions)
                        gate.resume(with: try? await session.respond(to: prompt).content)
                    }
                    Task {
                        try? await Task.sleep(for: timeout)
                        gate.resume(with: nil)
                        work.cancel()
                    }
                }
            }
        #endif
        return nil
    }

    static let japaneseInstructions = """
        あなたは箱庭ゲーム「ひびまち」に住む、やさしい生き物です。
        プレイヤーが現実でやったことの記録を読んで、ひとことだけ返します。
        ・日本語で1〜2文、60文字以内。
        ・記録に書かれた具体的なこと（やったこと、量、ひとこと、写真に写っているもの）にひとつ触れてから、ねぎらう。
          例: 「あたりを描けたんだね。形が見えてくるとわくわくするね。」
        ・「頑張ったね」だけのような、どの記録にも言える返事にしない。点数や評価はつけない。
        ・本当にやったか、どれだけ上手かを決めつけない。命令や説教をしない。
        ・記録に書かれていないことを作らない。
        """

    static let englishInstructions = """
        You are a gentle creature living in the island game Hibimachi.
        Read the record of something the player did in real life and reply with one short sentence.
        - English, one or two sentences, at most 25 words.
        - Mention one concrete thing from the record (what was done, the amount, the note, what is in the photo), \
        then encourage. Example: "You sketched the outline! It's exciting when the shape starts to show."
        - Never reply with something that fits any record, like only "Good job". No scores or grades.
        - Never judge whether it really happened or how well it was done. No orders or lectures.
        - Do not invent anything that is not in the record.
        """
}

/// Resumes a continuation once, with whichever answer arrives first.
private final class FirstAnswer: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?

    init(_ continuation: CheckedContinuation<String?, Never>) { self.continuation = continuation }

    func resume(with answer: String?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: answer)
    }
}
