//
//  FileThumbnailView.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//


import SwiftUI
import AppKit
import QuickLookThumbnailing

// MARK: - FileThumbnailView
struct FileThumbnailView: View {
    let url: URL
    let thumbnailSize: ThumbnailSize

    @State private var thumbnailImage: NSImage? = nil

    var body: some View {
        Group {
            if let thumbnailImage = thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: thumbnailSize.size.width, height: thumbnailSize.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: thumbnailSize.size.width, height: thumbnailSize.size.height)
                    .overlay(ProgressView())
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: CGSize(width: 256, height: 256),
                                                   scale: scale,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    thumbnailImage = thumbnail.nsImage
                }
            }
        }
    }
}
