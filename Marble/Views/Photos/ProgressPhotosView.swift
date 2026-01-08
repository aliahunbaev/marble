import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @State private var showingImagePicker = false
    @State private var selectedPhoto: ProgressPhoto?

    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            if photos.isEmpty {
                ContentUnavailableView(
                    "No progress photos",
                    systemImage: "camera.fill",
                    description: Text("Tap + to add your first photo")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            Button {
                                selectedPhoto = photo
                            } label: {
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                        .clipped()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            NavigationStack {
            }
            .navigationTitle("PROGRESS")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                AddProgressPhotoView()
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, onDelete: {
                    modelContext.delete(photo)
                    selectedPhoto = nil
                })
            }
        }
    }
}

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }

                VStack(alignment: .leading, spacing: MarbleSpacing.xs) {
                    VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
                        Text("DATE")
                            .font(.marbleDataLabel)
                            .tracking(2)
                            .foregroundColor(.marbleSecondary)
                        Text(photo.date.formatted(date: .long, time: .shortened))
                            .font(.marbleBody)
                            .foregroundColor(.marblePrimary)
                    }

                    if let notes = photo.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
                            Text("NOTES")
                                .font(.marbleDataLabel)
                                .tracking(2)
                                .foregroundColor(.marbleSecondary)
                            Text(notes)
                                .font(.marbleBody)
                                .foregroundColor(.marblePrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MarbleSpacing.xs)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

#Preview {
    ProgressPhotosView()
        .modelContainer(for: [ProgressPhoto.self])
}
