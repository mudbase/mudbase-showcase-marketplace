import SwiftUI

struct ListingStatusBadge: View {
    let status: ListingStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .open: return .green
        case .inProgress: return .orange
        case .completed: return .secondary
        }
    }
}
