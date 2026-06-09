// Models.swift
import SwiftUI

/// 灵感的 6 大分类（给氛围开发者的「人话」标签）
enum Category: String, CaseIterable, Identifiable {
    case idea   = "我想做什么"
    case flow   = "它怎么运作"
    case tool   = "用什么来做"
    case step   = "先做哪后做哪"
    case look   = "它长什么样"
    case source = "灵感来源"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .idea: return "💡"; case .flow: return "🔄"; case .tool: return "🧰"
        case .step: return "📍"; case .look: return "🎨"; case .source: return "🔗"
        }
    }
    var color: Color {
        switch self {
        case .idea: return Theme.catIdea; case .flow: return Theme.catFlow
        case .tool: return Theme.catTool; case .step: return Theme.catStep
        case .look: return Theme.catLook; case .source: return Theme.catSource
        }
    }
    var label: String { "\(emoji) \(rawValue)" }
}

/// 笔记里的一个「块 / 模组」。文档式编辑，块按顺序排在正文流里。
enum Block: Identifiable {
    case paragraph(id: UUID = .init(), text: AttributedString)
    case heading(id: UUID = .init(), text: String)
    case todo(id: UUID = .init(), items: [TodoItem])
    case mindMap(id: UUID = .init(), title: String)
    case github(id: UUID = .init(), repo: String, desc: String, stars: String)
    case video(id: UUID = .init(), title: String, duration: String)

    var id: UUID {
        switch self {
        case .paragraph(let id, _), .heading(let id, _), .todo(let id, _),
             .mindMap(let id, _), .github(let id, _, _, _), .video(let id, _, _):
            return id
        }
    }
}

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var done: Bool
}

/// 一本笔记 = 一个「待开发的系统主题」
struct Note: Identifiable {
    let id = UUID()
    var folder: String
    var category: Category
    var title: String
    var date: String
    var blocks: [Block]
}

// MARK: - 示例数据

extension Note {
    static var sample: Note {
        var p1 = AttributedString("核心体验：用户说一句「我想去海边放松三天」，App 就直接生成可编辑的每日行程。关键在于 AI 要先把这句模糊的话，拆成 ")
        var key = AttributedString("地点 · 天数 · 偏好")
        key.backgroundColor = Theme.highlight
        key.foregroundColor = Theme.highlightInk
        let p2 = AttributedString(" 三个字段，再去调外部数据。")
        p1.append(key); p1.append(p2)

        return Note(
            folder: "AI 旅行助手",
            category: .flow,
            title: "主流程：从一句话到行程卡",
            date: "2026年6月9日　下午2:20",
            blocks: [
                .paragraph(text: p1),
                .heading(text: "要想清楚的几件事"),
                .todo(items: [
                    TodoItem(text: "对话怎么收集偏好（预算？人数？）", done: true),
                    TodoItem(text: "行程卡片长什么样", done: true),
                    TodoItem(text: "API 查不到时给用户看什么", done: false),
                ]),
                .mindMap(title: "心智图"),
                .paragraph(text: AttributedString("后端先用现成的，别自己造轮子 👇")),
                .github(repo: "supabase / supabase",
                        desc: "开源后端 · 用户 / 数据库 / 登录一把梭 · ★ 72k",
                        stars: "72k"),
            ]
        )
    }
}
