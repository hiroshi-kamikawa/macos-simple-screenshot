import AppKit
import ScreenCaptureKit

enum CaptureAction: UInt32, CaseIterable {
    case screenImage = 1, areaImage, windowImage, screenVideo, areaVideo, windowVideo
}

enum AnnotationTool: Int {
    case select, text, arrow, rectangle
}

struct WindowChoice {
    let window: SCWindow
    let frame: CGRect
}

enum CaptureError: LocalizedError {
    case cancelled
    case noDisplay
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: "キャンセルしました。"
        case .noDisplay: "撮影対象のディスプレイが見つかりません。"
        case .exportFailed: "動画の保存に失敗しました。"
        }
    }
}
