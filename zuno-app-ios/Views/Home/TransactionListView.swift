import SwiftUI
import SwiftData

/// Full transaction history list
struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var transactionViewModel: TransactionViewModel

    @State private var selectedFilter: TransactionFilter = .all
    @State private var isRefreshing = false

    init(modelContext: ModelContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(modelContext: modelContext))
    }

    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case sent = "Sent"
        case received = "Received"
        case pending = "Pending"

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .sent: return "arrow.up.right"
            case .received: return "arrow.down.left"
            case .pending: return "clock"
            }
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Pills
                filterPills

                // Transaction List
                if transactionViewModel.transactions.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                            Section {
                                ForEach(groupedTransactions[date] ?? []) { transaction in
                                    NavigationLink {
                                        TransactionDetailView(transaction: transaction)
                                    } label: {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color(.secondarySystemBackground))
                                }
                            } header: {
                                Text(formatSectionHeader(date))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshTransactions()
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await transactionViewModel.loadAllTransactions()
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        Task {
                            await applyFilter(filter)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No transactions")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Your transaction history will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grouped Transactions

    private var groupedTransactions: [String: [LocalTransaction]] {
        Dictionary(grouping: transactionViewModel.transactions) { transaction in
            formatDate(transaction.createdAt)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    private func formatSectionHeader(_ dateString: String) -> String {
        return dateString
    }

    // MARK: - Filter Application

    private func applyFilter(_ filter: TransactionFilter) async {
        switch filter {
        case .all:
            await transactionViewModel.clearFilters()
        case .sent:
            await transactionViewModel.filterByType(.send)
        case .received:
            await transactionViewModel.filterByType(.receive)
        case .pending:
            await transactionViewModel.filterByStatus(.pending)
        }
    }

    private func refreshTransactions() async {
        isRefreshing = true
        await transactionViewModel.refreshAllTransactions()
        await applyFilter(selectedFilter)
        isRefreshing = false
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionListView(modelContext: ModelContext(ModelContainer.preview))
    }
}
