import Foundation
import ScreenCaptureKit

enum RecordingCaptureEntry {
    /// One press and it's recording: the display under the pointer, with the
    /// saved audio and camera choices, no setup and no countdown.
    static func recordScreenUnderPointer() {
        guard ScreenRecordingManager.ensureScreenCapturePermission() else { return }
        // Read before the first await, so the display is the one under the
        // pointer at the moment of the press.
        let screen = ActiveDisplayResolver.activeScreen(preferPointer: true)
        let displayID = screen.flatMap(ActiveDisplayResolver.displayID(for:))
        Task {
            do {
                let content = try await ScreenRecordingCapture.availableContent()
                guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
                    throw CocoaError(.featureUnsupported)
                }
                ScreenRecordingManager.shared.startRecording(source: ScreenRecordingSource(kind: .fullscreen(display)))
            } catch {
                ToastWindow.shared.show(isError: true, title: "Couldn’t start recording",
                    message: "No screen is available to record. Try again.",
                    systemIcon: "exclamationmark.triangle", on: screen)
            }
        }
    }

    static func recordFullscreen(_ display: SCDisplay) {
        Task {
            await CaptureCountdownPresenter.shared.runIfNeeded(
                seconds: BetterShotPreferences.recordingStartDelaySeconds,
                displayID: display.displayID
            )
            ScreenRecordingManager.shared.startRecording(source: ScreenRecordingSource(kind: .fullscreen(display)))
        }
    }

    static func recordWindow(_ window: SCWindow) {
        Task {
            let displayID = ActiveDisplayResolver.activeDisplayID(preferPointer: true)
            await CaptureCountdownPresenter.shared.runIfNeeded(
                seconds: BetterShotPreferences.recordingStartDelaySeconds,
                displayID: displayID
            )
            ScreenRecordingManager.shared.startRecording(source: ScreenRecordingSource(kind: .window(window)))
        }
    }

    static func recordArea() {
        RecordingAreaSelectionPresenter.shared.selectArea { display, rect in
            Task {
                await CaptureCountdownPresenter.shared.runIfNeeded(
                    seconds: BetterShotPreferences.recordingStartDelaySeconds,
                    displayID: display.displayID
                )
                ScreenRecordingManager.shared.startRecording(
                    source: ScreenRecordingSource(kind: .area(display: display, rect: rect))
                )
            }
        }
    }
}
