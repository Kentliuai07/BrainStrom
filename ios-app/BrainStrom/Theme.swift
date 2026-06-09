// Theme.swift
import SwiftUI

/// 全局配色与排版常量。颜色尽量贴近 Apple Notes 的暖白纸面 + 品牌渐变。
enum Theme {
    // 纸面 / 背景
    static let paper       = Color(hex: 0xFFFEFB)   // 笔记纸面（暖白）
    static let groupedBG   = Color(hex: 0xF2F2F7)   // iOS 分组背景
    static let toolbarBG   = Color(hex: 0xF6F5F1)

    // 文字
    static let ink         = Color(hex: 0x1C1C1E)   // 主文字
    static let body        = Color(hex: 0x2C2C2E)
    static let secondary   = Color(hex: 0x9A9AA0)
    static let faint       = Color(hex: 0xB7B7BC)

    // 强调色
    static let notesYellow = Color(hex: 0xF5B800)   // Apple Notes 黄（待办圈 / 文件夹）
    static let folderTint  = Color(hex: 0xE0A100)
    static let highlight   = Color(hex: 0xFFF3C4)   // 正文高亮底
    static let highlightInk = Color(hex: 0x7A5C00)

    // 品牌渐变（AI / 加模组按钮）
    static let brand = LinearGradient(
        colors: [Color(hex: 0x6366F1), Color(hex: 0xD946EF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // 分类色
    static let catIdea   = Color(hex: 0xF5B800)
    static let catFlow   = Color(hex: 0x0EA5E9)
    static let catTool   = Color(hex: 0x8B5CF6)
    static let catStep   = Color(hex: 0x10B981)
    static let catLook   = Color(hex: 0xF43F5E)
    static let catSource = Color(hex: 0x94A3B8)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// 轻量卡片阴影（模组内嵌用）
extension View {
    func embedShadow() -> some View {
        self.shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .shadow(color: Color(hex: 0x141428).opacity(0.10), radius: 14, y: 8)
    }
}
