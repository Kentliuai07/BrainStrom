import Foundation

// ============================================================
// 第3模式 · 批量生成定位卡(Persona) 的资料模型与串流事件
// 候选只活在记忆体(不落库),挑中一张才写进 SystemSpec 建专案。
// ============================================================

/// 一张 AI 生成的定位候选（身份证草稿）：8 个字段，对应 SystemSpec 理念区＋核心功能。技术栈不在此（挑中后守门员确认）。
struct PersonaCard: Equatable, Sendable, Codable, Identifiable {
    var id = UUID()
    var oneLiner: String = ""
    var targetUser: String = ""
    var painPoint: String = ""
    var coreValue: String = ""
    var marketStrategy: String = ""
    var businessModel: String = ""
    var coreFeatures: String = ""
    var tagline: String = ""

    enum CodingKeys: String, CodingKey {
        case oneLiner, targetUser, painPoint, coreValue, marketStrategy, businessModel, coreFeatures, tagline
    }
    init(oneLiner: String = "", targetUser: String = "", painPoint: String = "", coreValue: String = "",
         marketStrategy: String = "", businessModel: String = "", coreFeatures: String = "", tagline: String = "") {
        self.oneLiner = oneLiner; self.targetUser = targetUser; self.painPoint = painPoint; self.coreValue = coreValue
        self.marketStrategy = marketStrategy; self.businessModel = businessModel; self.coreFeatures = coreFeatures; self.tagline = tagline
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        oneLiner = (try? c.decode(String.self, forKey: .oneLiner)) ?? ""
        targetUser = (try? c.decode(String.self, forKey: .targetUser)) ?? ""
        painPoint = (try? c.decode(String.self, forKey: .painPoint)) ?? ""
        coreValue = (try? c.decode(String.self, forKey: .coreValue)) ?? ""
        marketStrategy = (try? c.decode(String.self, forKey: .marketStrategy)) ?? ""
        businessModel = (try? c.decode(String.self, forKey: .businessModel)) ?? ""
        coreFeatures = (try? c.decode(String.self, forKey: .coreFeatures)) ?? ""
        tagline = (try? c.decode(String.self, forKey: .tagline)) ?? ""
    }
}

extension PersonaCard {
    /// 挑中这张 → 组成系统身份证（写进现有 7 个理念字段，非空者标已确认；技术栈留空给守门员）。
    func toSpec(name: String) -> SystemSpec {
        func ne(_ s: String) -> String? { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }
        var confirmed: [String] = []
        let pairs: [(String, String)] = [("oneLiner", oneLiner), ("targetUser", targetUser), ("painPoint", painPoint),
            ("coreValue", coreValue), ("marketStrategy", marketStrategy), ("businessModel", businessModel), ("coreFeatures", coreFeatures)]
        for (k, v) in pairs where ne(v) != nil { confirmed.append(k) }
        return SystemSpec(
            name: ne(name),
            oneLiner: ne(oneLiner), targetUser: ne(targetUser), painPoint: ne(painPoint),
            coreValue: ne(coreValue), marketStrategy: ne(marketStrategy), businessModel: ne(businessModel),
            coreFeatures: ne(coreFeatures), confirmedFields: confirmed)
    }
}

/// 三轨搜寻结果（4 张候选共用同一份）。
struct PersonaSearchBundle: Equatable, Sendable, Codable {
    var competitors: [CompetitorItem] = []
    var articles: [CompetitorItem] = []
    var openSource: [CompetitorItem] = []
    var partial: Bool = false
}

/// persona 专用串流事件（带 index，不混进通用 AIEvent）。
enum PersonaEvent: Equatable, Sendable {
    case progress(message: String?)                 // 心跳/阶段提示
    case searchResults(PersonaSearchBundle)         // search_done：4 张共用
    case cardStart(index: Int)                      // 第 index 张开始
    case delta(index: Int, text: String)            // 第 index 张的串流文字（喂打字机）
    case cardDone(index: Int, card: PersonaCard)    // 第 index 张定稿（权威 8 字段）
    case usage(AIUsage)
    case done
    case error(code: String, message: String)
}
