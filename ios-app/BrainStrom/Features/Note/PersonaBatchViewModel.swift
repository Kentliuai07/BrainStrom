import SwiftUI

// ============================================================
// 第3模式 · 批量生成定位卡 ViewModel —— 消费 generatePersonas 串流
// loading(先搜+生成) → browsing(单张大卡切换) ；单卡重生不重搜(共用 sharedSearch)
// ============================================================

@MainActor
@Observable
final class PersonaBatchViewModel {

    enum Phase: Equatable { case loading, browsing, failed }

    private let ai: any AIServicing
    private let slots: Int

    var phase: Phase = .loading
    var progress: String = ""
    var search: PersonaSearchBundle?
    var cards: [PersonaCard]          // index 对齐的定稿卡（占位空卡填充）
    var drafts: [String]              // 每张串流中的草稿文字（喂打字机）
    var ready: [Bool]                 // 每张是否已 card_done
    var current: Int = 0              // 大卡当前第几张
    var regeneratingIndex: Int?       // 正在重生哪张（browsing 中局部 spinner）
    var errorMessage: String?
    let typewriter = TypewriterBuffer()

    private(set) var appName = ""
    private(set) var oneLiner = ""
    private(set) var country = ""
    private var task: Task<Void, Never>?

    init(ai: any AIServicing, slots: Int = 4) {
        self.ai = ai
        self.slots = slots
        cards = Array(repeating: PersonaCard(), count: slots)
        drafts = Array(repeating: "", count: slots)
        ready = Array(repeating: false, count: slots)
    }

    /// 任一张已就绪。
    var hasAnyCard: Bool { ready.contains(true) }

    func start(appName: String, oneLiner: String, country: String) {
        self.appName = appName; self.oneLiner = oneLiner; self.country = country
        phase = .loading; progress = ""; errorMessage = nil; search = nil
        cards = Array(repeating: PersonaCard(), count: slots)
        drafts = Array(repeating: "", count: slots)
        ready = Array(repeating: false, count: slots)
        current = 0
        typewriter.reset()
        run(regenerateIndex: nil)
    }

    /// 单卡重生（不重搜，把其他张当负面提示）。
    func regenerate(_ index: Int) {
        guard index >= 0, index < slots, regeneratingIndex == nil else { return }
        regeneratingIndex = index
        drafts[index] = ""; ready[index] = false
        typewriter.reset()
        run(regenerateIndex: index)
    }

    func cancel() { task?.cancel() }

    private func run(regenerateIndex: Int?) {
        task?.cancel()
        let avoid: [PersonaCard] = regenerateIndex == nil ? [] : cards.enumerated()
            .filter { $0.offset != regenerateIndex && ready[$0.offset] }.map { $0.element }
        let shared = regenerateIndex == nil ? nil : search
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await ev in ai.generatePersonas(appName: appName, oneLiner: oneLiner, country: country,
                                                         regenerateIndex: regenerateIndex, avoidCards: avoid, sharedSearch: shared) {
                    guard !Task.isCancelled else { break }
                    switch ev {
                    case .progress(let m):
                        if let m { progress = m }
                    case .searchResults(let b):
                        search = b
                    case .cardStart(let i):
                        guard i >= 0, i < slots else { break }
                        drafts[i] = ""; ready[i] = false
                        if phase == .loading { phase = .browsing }
                        current = i                       // 跟着正在生成的卡
                        typewriter.reset()
                    case .delta(let i, let t):
                        guard i >= 0, i < slots else { break }
                        drafts[i] += t
                        if i == current { typewriter.setTarget(drafts[i]) }
                    case .cardDone(let i, let card):
                        guard i >= 0, i < slots else { break }
                        cards[i] = card; ready[i] = true
                        if i == current { typewriter.finish() }
                    case .usage:
                        break
                    case .done:
                        typewriter.finish()
                        if !hasAnyCard { phase = .failed; errorMessage = errorMessage ?? String(localized: "AI 沒有產出定位，請重試") }
                        else { phase = .browsing }
                        regeneratingIndex = nil
                    case .error(_, let msg):
                        if !hasAnyCard { phase = .failed; errorMessage = msg.isEmpty ? String(localized: "生成失敗，請重試") : msg }
                        regeneratingIndex = nil
                    }
                }
            } catch is CancellationError {
                regeneratingIndex = nil
            } catch {
                if !hasAnyCard { phase = .failed; errorMessage = String(localized: "連線出錯，請稍後再試") }
                regeneratingIndex = nil
            }
        }
    }
}
