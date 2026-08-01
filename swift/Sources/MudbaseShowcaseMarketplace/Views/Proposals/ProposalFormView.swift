import SwiftUI

/// Mirrors `../web/src/components/proposals/ProposalForm.tsx` — embedded inside
/// `ListingDetailView`'s "Your proposal" section (not its own `Form`/screen), so validation is
/// re-implemented as plain checks rather than zod.
struct ProposalFormView: View {
    @State private var coverLetter = ""
    @State private var proposedRateText = ""
    @State private var localErrorMessage: String?
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: (ProposalDraft) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = errorMessage ?? localErrorMessage {
                InlineBanner(message: message)
            }
            Text("Cover letter").font(.caption).foregroundStyle(.secondary)
            TextField("Explain why you're a good fit…", text: $coverLetter, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            Text("Proposed rate (USD)").font(.caption).foregroundStyle(.secondary)
            TextField("0", text: $proposedRateText)
                .numberPadKeyboard()
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Submit proposal")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
        .padding(.vertical, 4)
    }

    private func submit() async {
        let trimmed = coverLetter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else {
            localErrorMessage = "Cover letter must be at least 20 characters"
            return
        }
        guard let rate = Double(proposedRateText), rate > 0 else {
            localErrorMessage = "Proposed rate must be greater than 0"
            return
        }
        localErrorMessage = nil
        await onSubmit(ProposalDraft(coverLetter: trimmed, proposedRate: rate))
        coverLetter = ""
        proposedRateText = ""
    }
}
