import PencilKit
import SwiftUI
import UIKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = true
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        applyAppearance(canvas, colorScheme: colorScheme)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        applyAppearance(uiView, colorScheme: colorScheme)
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    private func applyAppearance(_ canvas: PKCanvasView, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        canvas.backgroundColor = isDark
            ? UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1)
            : UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1)
        canvas.tool = PKInkingTool(
            .pen,
            color: isDark
                ? UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
                : UIColor(red: 0.11, green: 0.16, blue: 0.20, alpha: 1),
            width: 2.6
        )
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}
