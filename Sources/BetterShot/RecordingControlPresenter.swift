//
//  RecordingControlPresenter.swift
//  BetterShot
//
//  Created by Codex on 01/05/26.
//
//  The in-session mode of the floating bar: elapsed time and the transport
//  controls for the recording that's running. It shares its panel and chrome
//  with the pre-record picker (RecordingPickerBar), so starting a recording
//  morphs one into the other instead of swapping windows.
//

import AppKit
import SwiftUI

/// Retained as the entry point callers already use; the bar itself is owned
/// by RecordingBarPresenter.
@MainActor
enum RecordingControlPresenter {
    static var shared: RecordingBarPresenter { RecordingBarPresenter.shared }
}

extension RecordingBarPresenter {
    func show(displayID: CGDirectDisplayID?) {
        showRecording(displayID: displayID)
    }
}

// MARK: - Controls

struct RecordingSessionControls: View {
    @State private var manager = ScreenRecordingManager.shared
    @State private var presenter = RecordingBarPresenter.shared

    private var isPaused: Bool {
        manager.state == .paused
    }

    /// Starting and finishing are both moments where the transport can't
    /// safely be driven - the capture graph is being wired up or torn down.
    private var isSettling: Bool {
        manager.state == .starting || manager.state == .finishing
    }

    private var settlingTitle: String? {
        switch manager.state {
        case .starting: "Preparing"
        case .finishing: "Saving"
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            status
                .padding(.leading, 14)
                .padding(.trailing, 10)

            Rectangle()
                .fill(BarMetrics.stroke)
                .frame(width: 1, height: 18)

            HStack(spacing: 2) {
                if manager.isMicrophoneActive {
                    BarActionButton(
                        id: .microphoneMute,
                        title: manager.isMicrophoneMuted ? "Unmute microphone" : "Mute microphone",
                        systemImage: manager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                        tint: manager.isMicrophoneMuted ? BarMetrics.recordTint : BarMetrics.activeTint,
                        isCompact: true
                    ) {
                        manager.toggleMicrophoneMute()
                    }
                }

                BarActionButton(
                    id: .pauseResume,
                    title: isPaused ? "Resume recording" : "Pause recording",
                    systemImage: isPaused ? "play.fill" : "pause.fill",
                    isCompact: true
                ) {
                    if isPaused { manager.resumeRecording() }
                    else { manager.pauseRecording() }
                }

                BarActionButton(
                    id: .stop,
                    title: "Stop and save",
                    systemImage: "stop.fill",
                    tint: BarMetrics.recordTint,
                    isCompact: true,
                    accessibility: "Stop and save recording, \(manager.formattedElapsedTime) elapsed"
                ) {
                    manager.stopRecording()
                }

                BarActionButton(id: .restart, title: "Start over", systemImage: "arrow.counterclockwise", isCompact: true) {
                    presenter.confirmRecordingAction(.restartRecording)
                }

                BarActionButton(id: .discard, title: "Discard recording", systemImage: "xmark", isCompact: true) {
                    presenter.confirmRecordingAction(.discardRecording)
                }
            }
            .disabled(isSettling)
            .padding(.leading, 6)
            .padding(.trailing, 4)
        }
    }

    private var status: some View {
        HStack(spacing: 8) {
            if isSettling {
                ProgressView().controlSize(.mini)
            } else {
                Circle()
                    .fill(isPaused ? Color(nsColor: .systemOrange) : BarMetrics.recordTint)
                    .frame(width: 8, height: 8)
            }
            Text(settlingTitle ?? manager.formattedElapsedTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(BarMetrics.activeTint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(settlingTitle ?? "\(isPaused ? "Paused" : "Recording"), \(manager.formattedElapsedTime) elapsed")
    }
}
