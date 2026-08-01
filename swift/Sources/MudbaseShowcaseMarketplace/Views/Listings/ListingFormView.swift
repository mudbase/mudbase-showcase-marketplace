import SwiftUI

/// Mirrors `../web/src/components/listings/ListingForm.tsx` — handles both "Post a new listing"
/// and "Edit listing".
struct ListingFormView: View {
    @StateObject private var viewModel: ListingFormViewModel
    @Environment(\.dismiss) private var dismiss
    var onSaved: ((String) -> Void)?

    init(config: AppConfig, clientId: String, clientName: String, existingListing: Listing? = nil, onSaved: ((String) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ListingFormViewModel(config: config, clientId: clientId, clientName: clientName, existingListing: existingListing))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            if let errorMessage = viewModel.errorMessage {
                Section { InlineBanner(message: errorMessage) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Details") {
                TextField("Title", text: $viewModel.draft.title)
                TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                    .lineLimit(4...8)
                TextField("Category (optional)", text: $viewModel.draft.category)
            }

            Section("Budget") {
                LabeledContent("Budget (USD)") {
                    TextField("0", value: $viewModel.draft.budget, format: .number)
                        .numberPadKeyboard()
                        .multilineTextAlignment(.trailing)
                }
            }

            if viewModel.isEditing {
                Section("Status") {
                    Picker("Status", selection: $viewModel.draft.status) {
                        ForEach(ListingStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.save()
                        if viewModel.didSave {
                            if let id = viewModel.savedListingId { onSaved?(id) }
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text(viewModel.isEditing ? "Save changes" : "Post listing")
                    }
                }
                .disabled(viewModel.isSubmitting)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit listing" : "Post a new listing")
        .inlineNavigationTitle()
    }
}
