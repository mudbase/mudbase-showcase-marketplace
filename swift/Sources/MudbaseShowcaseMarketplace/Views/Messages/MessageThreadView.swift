import SwiftUI

/// Mirrors `../web/src/components/messages/MessageThread.tsx` — embedded inside
/// `ListingDetailView`'s "Messages" section (only rendered for the client or the accepted
/// freelancer, see `plan/build-plan.md` "Messaging visibility"). A fixed-height inner `ScrollView`
/// mirrors the web version's `max-h-96 overflow-y-auto` div — it scrolls independently of the
/// outer `List`/`Form` it's embedded in.
struct MessageThreadView: View {
    @StateObject private var viewModel: MessageThreadViewModel
    let currentUser: AppUser

    init(config: AppConfig, listingId: String, currentUser: AppUser) {
        _viewModel = StateObject(wrappedValue: MessageThreadViewModel(config: config, listingId: listingId))
        self.currentUser = currentUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visible to the client and the accepted freelancer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else if viewModel.messages.isEmpty {
                            Text("No messages yet — say hello.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message, isOwn: message.senderId == currentUser.id)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 260)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                InlineBanner(message: errorMessage)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Write a message…", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button {
                    Task { await viewModel.send(currentUser: currentUser) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(viewModel.isSending || viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.vertical, 4)
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }
}

private struct MessageBubbleView: View {
    let message: Message
    let isOwn: Bool

    var body: some View {
        HStack(alignment: .top) {
            if isOwn { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 2) {
                Text(message.content)
                    .font(.subheadline)
                Text("\(message.senderName) · \(Formatting.relativeTime(from: message.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(isOwn ? .white.opacity(0.8) : .secondary)
            }
            .padding(8)
            .background(isOwn ? Color.accentColor : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(isOwn ? .white : .primary)
            if !isOwn { Spacer(minLength: 32) }
        }
    }
}
