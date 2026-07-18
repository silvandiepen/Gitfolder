import GitKit
import SwiftUI

/// Hosts the task detail in its own window, looking up the live card by id so it
/// stays in sync with the board and closes if the task is deleted.
struct TaskDetailWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let cardID: String

    private var card: Card? { model.allCards.first { $0.fields.id == cardID } }

    var body: some View {
        Group {
            if let card {
                CardDetailView(card: card)
            } else {
                ContentUnavailableView("Task not found", systemImage: "doc.text")
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        .navigationTitle(card?.fields.title ?? cardID)
        .onChange(of: card == nil) { _, gone in
            if gone { dismiss() }
        }
    }
}
