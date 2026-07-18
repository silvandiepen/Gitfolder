import GitKit
import SwiftUI

/// A card's detail: read mode renders the markdown body via Nizel; edit mode is a
/// plain-text editor over the raw `.md` file. Saving writes the file and commits +
/// pushes it to the live repo in the background.
struct CardDetailView: View {
    @Environment(AppModel.self) private var model
    let card: Card

    enum Mode: Hashable { case read, edit }

    @State private var mode: Mode = .read
    @State private var draft = ""
    @State private var isSaving = false

    private var editable: Bool { model.canEdit(card) }
    private var title: String { card.fields.title.isEmpty ? card.fields.id : card.fields.title }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 520, minHeight: 460)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(2)
                metadata
            }
            Spacer(minLength: 12)
            Text(model.syncStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            if editable {
                Picker("", selection: $mode) {
                    Text("Read").tag(Mode.read)
                    Text("Edit").tag(Mode.edit)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                if mode == .edit {
                    Button("Save", action: save)
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(isSaving)
                }
            }
            Button("Done") { model.selectedCard = nil }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
        .onChange(of: mode) { _, newValue in
            if newValue == .edit {
                draft = model.rawText(for: card) ?? card.body
            }
        }
    }

    @ViewBuilder private var metadata: some View {
        HStack(spacing: 8) {
            if let priority = card.fields.priority {
                Text(priority).font(.caption2).foregroundStyle(.secondary)
            }
            if let assignee = card.fields.assignee {
                Text("@\(assignee)").font(.caption2).foregroundStyle(.secondary)
            }
            if let status = statusLabel {
                Text(status).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var statusLabel: String? {
        card.fields.status.isEmpty ? nil : card.fields.status
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .read:
            MarkdownWebView(markdown: card.body)
        case .edit:
            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .padding(8)
        }
    }

    private func save() {
        isSaving = true
        let text = draft
        Task {
            await model.saveCard(card, text: text)
            isSaving = false
            mode = .read
        }
    }
}
