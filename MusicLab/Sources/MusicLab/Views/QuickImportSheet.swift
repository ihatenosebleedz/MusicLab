import SwiftUI
import MusicLabCore

public struct QuickImportSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var urlInput: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Paste any Apple Music album, song, or playlist URL to enqueue it for download.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                TextField("https://music.apple.com/...", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                Button {
                    appState.submitUrlImport(url: urlInput)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Download Queue")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .foregroundStyle(.white)
                    .background(urlInput.isEmpty ? Color.gray.opacity(0.4) : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .disabled(urlInput.isEmpty)
                
                Spacer()
            }
            .padding()
            .background(Theme.background)
            .navigationTitle("Import Apple Music URL")
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
