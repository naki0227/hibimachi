import PhotosUI
import SwiftUI
import UIKit

/// "写真をとる": the camera when the device has one, or a photo from the library (system picker, no library
/// permission). Hands back a JPEG already shrunk and stripped of metadata (`PhotoPrep`).
struct PhotoCaptureButton: View {
    let title: String
    let identifier: String
    let picked: (Data) -> Void
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?

    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        Menu {
            if hasCamera {
                Button {
                    showingCamera = true
                } label: {
                    Label("カメラで撮る", systemImage: "camera")
                }
            }
            Button {
                showingLibrary = true
            } label: {
                Label("写真からえらぶ", systemImage: "photo.on.rectangle")
            }
        } label: {
            Label(title, systemImage: "camera.fill").frame(maxWidth: .infinity)
        }
        .menuStyle(.button)
        .buttonStyle(.game(.secondary, compact: true))
        .accessibilityIdentifier(identifier)
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in
                showingCamera = false
                if let data { prepare(data) }
            }
            .ignoresSafeArea()
        }
        .task(id: libraryItem) {
            guard let libraryItem, let data = try? await libraryItem.loadTransferable(type: Data.self) else { return }
            self.libraryItem = nil
            prepare(data)
        }
    }

    private func prepare(_ data: Data) {
        Task {
            // Decoding and resizing a large photo is CPU work; keep it off the main actor.
            if let jpeg = await Task.detached(operation: { PhotoPrep.albumJPEG(from: data) }).value { picked(jpeg) }
        }
    }
}

/// The system camera. Returns the photo's JPEG data, or `nil` when cancelled.
private struct CameraPicker: UIViewControllerRepresentable {
    let done: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (Data?) -> Void

        init(done: @escaping (Data?) -> Void) {
            self.done = done
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            done(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            done(nil)
        }
    }
}
