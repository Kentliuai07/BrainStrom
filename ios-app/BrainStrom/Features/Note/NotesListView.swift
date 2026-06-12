import SwiftUI

// ============================================================
// 開發筆記 · 多筆記清單（階段三 第 3 刀）
// 一個專案可有多篇筆記；點一篇進編輯頁，＋新增，左滑刪除。
// ============================================================

struct NotesListView: View {

    let systemID: UUID
    @Binding var path: NavigationPath

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var notes: [Note] = []
    @State private var primaryID: UUID?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !loaded {
                    Text(String(localized: "載入中…"))
                        .font(Tokens.Fonts.body(13)).foregroundStyle(palette.print3)
                        .padding(.vertical, 20)
                } else if notes.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(notes) { note in noteRow(note) }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.top, Tokens.Spacing.s4)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .onAppear(perform: reload)
        .onChange(of: path) { _, new in if new.isEmpty || path.count <= 1 { reload() } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: "📝").font(.system(size: 18))
            Text(String(localized: "開發筆記"))
                .font(Tokens.Fonts.display(20, weight: .heavy))
                .foregroundStyle(palette.print)
            Spacer()
            Button {
                Haptics.press(); createNote()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text(String(localized: "新增")).font(Tokens.Fonts.body(13, weight: .semibold))
                }
                .padding(.horizontal, 12).frame(height: 36)
            }
            .buttonStyle(.keycap(.orange, cornerRadius: 10))
            .accessibilityIdentifier("noteslist.create")
        }
        .padding(.bottom, 14)
    }

    private func noteRow(_ note: Note) -> some View {
        Button {
            Haptics.tap()
            path.append(HomeRoute.noteDetail(noteID: note.id))
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if note.id == primaryID {
                        Text(String(localized: "主")).font(Tokens.Fonts.mono(8, weight: .bold))
                            .foregroundStyle(palette.orangeInk)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(palette.orange))
                    }
                    Text(note.title.isEmpty ? String(localized: "未命名筆記") : note.title)
                        .font(Tokens.Fonts.body(15, weight: .bold))
                        .foregroundStyle(palette.print)
                        .lineLimit(1)
                    if note.docState == .carded {
                        Text(String(localized: "卡片")).font(Tokens.Fonts.mono(8, weight: .bold))
                            .foregroundStyle(palette.orange)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(palette.orangeDim))
                    }
                    Spacer()
                    Text(note.updatedAt, format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
                }
                Text(snippet(of: note))
                    .font(Tokens.Fonts.body(12.5)).foregroundStyle(palette.print2)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .hardwareCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("noteslist.row")
        .contextMenu {
            Button(role: .destructive) { deleteNote(note.id) } label: {
                Label(String(localized: "刪除筆記"), systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(verbatim: "📝").font(.system(size: 34)).opacity(0.5)
            Text(String(localized: "還沒有筆記"))
                .font(Tokens.Fonts.body(14, weight: .semibold)).foregroundStyle(palette.print2)
            Button { Haptics.press(); createNote() } label: {
                Text(String(localized: "寫第一篇筆記"))
                    .font(Tokens.Fonts.body(14, weight: .semibold))
                    .frame(width: 170, height: 46)
            }
            .buttonStyle(.keycap(.orange))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private func snippet(of note: Note) -> String {
        let first = note.liveBlocks.first {
            ($0.kind == .paragraph || $0.kind == .heading1 || $0.kind == .heading2)
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let raw = (first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return String(localized: "（空白筆記，點開開始寫）") }
        return raw.count > 60 ? String(raw.prefix(60)) + "…" : raw
    }

    private func reload() {
        guard let repo = root.repository else { notes = []; loaded = true; return }
        let all = (try? repo.notes(in: systemID)) ?? []
        // 舊系統(build 5 無 primaryNoteID)：有筆記才順手回填(documentNote 內部把最近那篇設為主筆記)；
        // 新系統 primaryNoteID 已設→直返無副作用；0 筆記不呼叫，避免誤建。
        if !all.isEmpty { _ = try? repo.documentNote(for: systemID) }
        primaryID = try? repo.primaryNoteID(for: systemID)
        // 主筆記置頂，其餘按更新時間。
        notes = all.sorted { a, b in
            if a.id == primaryID { return true }
            if b.id == primaryID { return false }
            return a.updatedAt > b.updatedAt
        }
        loaded = true
    }

    private func createNote() {
        guard let repo = root.repository else { return }
        guard let note = try? repo.createNote(in: systemID, title: "") else { return }
        reload()
        path.append(HomeRoute.noteDetail(noteID: note.id))
    }

    private func deleteNote(_ id: UUID) {
        Haptics.warning()
        try? root.repository?.deleteNote(id: id)
        reload()
    }
}
