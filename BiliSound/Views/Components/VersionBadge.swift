import SwiftUI

/// Feature 4: Badge indicating available multi-versions for a song
public struct VersionBadge: View {
    let count: Int
    var isSelected: Bool = false
    
    public init(count: Int, isSelected: Bool = false) {
        self.count = count
        self.isSelected = isSelected
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "dice.fill")
                .font(.system(size: 9, weight: .bold))
            Text("\(count) versions")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(isSelected ? Color.pink.opacity(0.3) : Color.white.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.pink.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 0.8)
        )
        .foregroundColor(isSelected ? .pink : .white.opacity(0.85))
    }
}
