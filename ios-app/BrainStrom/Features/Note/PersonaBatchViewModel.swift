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
    private let initialCount: Int
    let maxCards = 6

    var phase: Phase = .loading
    var progress: String = ""
    var search: PersonaSearchBundle?
    var cards: [PersonaCard] = []     // 可增长；index 对齐
    var drafts: [String] = []         // 每张串流中的草稿文字（喂打字机）
    var ready: [Bool] = []            // 每张是否已 card_done
    var current: Int = 0              // 大卡当前第几张
    var busy = false                  // 串流中（禁止追加/重生/挑选）
    var regeneratingIndex: Int?       // 正在重生哪张（局部 spinner）
    var appendReason = ""             // 「想要什麼不一樣的」输入框绑定
    var errorMessage: String?
    let typewriter = TypewriterBuffer()

    private(set) var appName = ""
    private(set) var oneLiner = ""
    private(set) var country = ""
    private var task: Task<Void, Never>?

    init(ai: any AIServicing, initialCount: Int = 2) {
        self.ai = ai
        self.initialCount = max(1, initialCount)
    }

    var hasAnyCard: Bool { ready.contains(true) }
    /// 能否追加：不在串流中、已在浏览、未达上限。
    var canAppend: Bool { !busy && phase == .browsing && cards.count < maxCards }

    func start(appName: String, oneLiner: String, country: String) {
        self.appName = appName; self.oneLiner = oneLiner; self.country = country
        phase = .loading; progress = ""; errorMessage = nil; search = nil; current = 0
        cards = Array(repeating: PersonaCard(), count: initialCount)
        drafts = Array(repeating: "", count: initialCount)
        ready = Array(repeating: false, count: initialCount)
        typewriter.reset()
        run(mode: "batch", count: initialCount, regenerateIndex: nil, reason: "")
    }

    /// ＋再生成一張：追加一张新卡（不重搜、避开已有、贴合 appendReason）。
    func appendCard() {
        guard canAppend else { return }
        let reason = appendReason.trimmingCharacters(in: .whitespacesAndNewlines)
        appendReason = ""
        run(mode: "append", count: 1, regenerateIndex: nil, reason: reason)
    }

    /// 单卡重生（替换该张，不重搜）。
    func regenerate(_ index: Int) {
        guard !busy, index >= 0, index < cards.count else { return }
        regeneratingIndex = index
        drafts[index] = ""; ready[index] = false
        if current == index { typewriter.reset() }
        run(mode: "regenerate", count: 1, regenerateIndex: index, reason: "")
    }

    func cancel() { task?.cancel(); busy = false; regeneratingIndex = nil }

    /// 确保 cards/drafts/ready 至少有 index+1 个槽（追加卡自动扩容）。
    private func ensureSlot(_ i: Int) {
        while cards.count <= i { cards.append(PersonaCard()); drafts.append(""); ready.append(false) }
    }

    private func run(mode: String, count: Int, regenerateIndex: Int?, reason: String) {
        task?.cancel()
        // avoid = 已就绪的卡（append/regenerate 用来避重）；batch 不需要（后端逐张自累积）
        let avoid: [PersonaCard]
        switch mode {
        case "regenerate":
            avoid = cards.indices.filter { $0 != regenerateIndex && ready[$0] }.map { cards[$0] }
        case "append":
            avoid = cards.indices.filter { ready[$0] }.map { cards[$0] }
        default:
            avoid = []
        }
        let shared = (mode == "batch") ? nil : search
        busy = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await ev in ai.generatePersonas(appName: appName, oneLiner: oneLiner, country: country,
                                                         count: count, mode: mode, reason: reason,
                                                         regenerateIndex: regenerateIndex, avoidCards: avoid, sharedSearch: shared) {
                    guard !Task.isCancelled else { break }
                    switch ev {
                    case .progress(let m):
                        if let m { progress = m }
                    case .searchResults(let b):
                        search = b
                    case .cardStart(let i):
                        guard i >= 0 else { break }
                        ensureSlot(i)
                        drafts[i] = ""; ready[i] = false
                        if phase == .loading { phase = .browsing }
                        current = i                       // 跟着正在生成的卡
                        typewriter.reset()
                    case .delta(let i, let t):
                        guard i >= 0, i < drafts.count else { break }
                        drafts[i] += t
                        if i == current { typewriter.setTarget(drafts[i]) }
                    case .cardDone(let i, let card):
                        guard i >= 0 else { break }
                        ensureSlot(i)
                        cards[i] = card; ready[i] = true
                        if i == current { typewriter.finish() }
                    case .usage:
                        break
                    case .done:
                        typewriter.finish()
                        if !hasAnyCard { phase = .failed; errorMessage = errorMessage ?? String(localized: "AI 沒有產出定位，請重試") }
                        else { phase = .browsing }
                    case .error(_, let msg):
                        if !hasAnyCard { phase = .failed; errorMessage = msg.isEmpty ? String(localized: "生成失敗，請重試") : msg }
                    }
                }
                busy = false; regeneratingIndex = nil
            } catch is CancellationError {
                busy = false; regeneratingIndex = nil
            } catch {
                if !hasAnyCard { phase = .failed; errorMessage = String(localized: "連線出錯，請稍後再試") }
                busy = false; regeneratingIndex = nil
            }
        }
    }
}
