//
//  FileListItem.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//

import SwiftUI

struct FileListItem: View {
    var thumbnailSizePreference: ThumbnailSize
    var file: SelectedFile
    @Binding var selectedFiles: [SelectedFile]
    var processedFileName: String
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: thumbnailSizePreference == .large ? 16 : 8) {
            // Try to resolve URL from bookmark for thumbnail
            Group {
                if let url = resolveURL() {
                    FileThumbnailView(url: url, thumbnailSize: thumbnailSizePreference)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    // Fallback: show generic file icon if bookmark can't be resolved
                    Image(systemName: "doc.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: thumbnailSizePreference.size.width, height: thumbnailSizePreference.size.height)
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .lineLimit(1)
                Text("Selected file")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 16) {
                Image(systemName: "arrow.right")
                Text(processedFileName)
                    .foregroundColor(.secondary)
                Spacer(minLength: 4)
            }
            HStack {
                Spacer()
                if isHovering {
                    Button {
                        if let index = selectedFiles.firstIndex(where: { $0.id == file.id }) {
                            selectedFiles.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .padding(4)
                }
            }
            .frame(width: 32)
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation { isHovering = hovering }
        }
        
    }
    
    private func resolveURL() -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: file.bookmark, 
                       options: [.withSecurityScope], 
                       relativeTo: nil, 
                       bookmarkDataIsStale: &isStale)
    }
}

