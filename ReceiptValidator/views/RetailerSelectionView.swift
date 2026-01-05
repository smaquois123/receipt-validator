//
//  RetailerSelectionView.swift
//  ReceiptValidator
//
//  Created by JC Smith on 12/24/25.
//

import SwiftUI

struct RetailerSelectionView: View {
    @Binding var selectedRetailer: RetailerType?
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Select Retailer")
                            .font(.title2.bold())
                        
                        Text("Choose the store where you shopped")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Retailer Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(RetailerType.allRetailers, id: \.self) { retailer in
                            RetailerCard(retailer: retailer) {
                                selectedRetailer = retailer
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Choose Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RetailerCard: View {
    let retailer: RetailerType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: retailer.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(retailer.color)
                
                Text(retailer.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(retailer.color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RetailerType Extensions

extension RetailerType {
    static var allRetailers: [RetailerType] {
        [
            .walmart,
            .target,
            .costco,
            .kroger,
            .safeway,
            .wholeFoods,
            .atwoods,
            .tractorSupply,
            .homeDepot,
            .lowes,
            .unknown
        ]
    }
    
    var iconName: String {
        switch self {
        case .walmart:
            return "cart.fill"
        case .target:
            return "target"
        case .costco:
            return "building.2.fill"
        case .kroger:
            return "basket.fill"
        case .safeway:
            return "bag.fill"
        case .wholeFoods:
            return "leaf.fill"
        case .atwoods:
            return "tent.fill"
        case .tractorSupply:
            return "wrench.and.screwdriver.fill"
        case .homeDepot:
            return "hammer.fill"
        case .lowes:
            return "house.fill"
        case .unknown:
            return "questionmark.square.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .walmart:
            return .blue
        case .target:
            return .red
        case .costco:
            return .blue
        case .kroger:
            return .blue
        case .safeway:
            return .red
        case .wholeFoods:
            return .green
        case .atwoods:
            return .orange
        case .tractorSupply:
            return .green
        case .homeDepot:
            return .orange
        case .lowes:
            return .blue
        case .unknown:
            return .gray
        }
    }
}

#Preview {
    RetailerSelectionView(selectedRetailer: .constant(nil))
}
