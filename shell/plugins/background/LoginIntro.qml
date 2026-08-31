import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property string videoPath: ""
  property string backgroundPath: ""
  property string mode: "procedural"
  property bool running: false
  property real revealOpacity: 1
  property real cameraProgress: 0
  property int playSerial: 0
  property string finishReason: ""

  readonly property int fadeDuration: 450
  readonly property int proceduralDuration: 3200

  signal finished(string reason)

  function start(video, background) {
    background = String(background || "").trim()
    if (!background) return false

    motionAnimation.stop()
    proceduralFadeTimer.stop()
    fadeAnimation.stop()
    safetyTimer.stop()

    videoPath = String(video || "").trim()
    backgroundPath = background
    mode = videoPath ? "video" : "procedural"
    finishReason = ""
    revealOpacity = 1
    cameraProgress = 0
    running = true
    playSerial += 1

    if (mode === "procedural") {
      motionAnimation.restart()
      proceduralFadeTimer.restart()
      safetyTimer.interval = proceduralDuration + 2000
    } else {
      safetyTimer.interval = 30000
    }
    safetyTimer.restart()
    return true
  }

  function beginFade(reason) {
    if (!running || fadeAnimation.running) return
    finishReason = String(reason || "completed")
    proceduralFadeTimer.stop()
    safetyTimer.stop()
    fadeAnimation.restart()
  }

  function stop() {
    beginFade("stopped")
  }

  function statusObject() {
    return {
      running: running,
      mode: running ? mode : "idle",
      video: running ? videoPath : "",
      background: running ? backgroundPath : ""
    }
  }

  NumberAnimation {
    id: motionAnimation
    target: root
    property: "cameraProgress"
    from: 0
    to: 1
    duration: root.proceduralDuration
    easing.type: Easing.InOutCubic
  }

  Timer {
    id: proceduralFadeTimer
    interval: root.proceduralDuration - root.fadeDuration
    onTriggered: root.beginFade("completed")
  }

  NumberAnimation {
    id: fadeAnimation
    target: root
    property: "revealOpacity"
    from: 1
    to: 0
    duration: root.fadeDuration
    easing.type: Easing.InOutCubic
    onFinished: {
      var reason = root.finishReason || "completed"
      root.running = false
      root.videoPath = ""
      root.finished(reason)
    }
  }

  Timer {
    id: safetyTimer
    onTriggered: root.beginFade("timeout")
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.running && !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }

      WlrLayershell.namespace: "omarchy-login-intro"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // The intro is visual-only. Applications continue receiving pointer
      // input while the temporary layer fades away above them.
      mask: Region {}

      Item {
        anchors.fill: parent
        opacity: root.revealOpacity

        Image {
          anchors.fill: parent
          source: Util.fileUrl(root.backgroundPath)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: true
          scale: root.mode === "procedural" ? 1 + Math.sin(root.cameraProgress * Math.PI) * 0.035 : 1
        }

        Loader {
          id: videoLoader
          anchors.fill: parent
          active: root.running && root.mode === "video"
          asynchronous: true
          source: active ? "LoginIntroVideo.qml" : ""

          onLoaded: {
            item.fadeRequested.connect(function(reason) { root.beginFade(reason) })
            item.start(root.videoPath, root.fadeDuration)
          }
        }
      }

      Connections {
        target: root

        function onPlaySerialChanged() {
          if (videoLoader.item && root.running && root.mode === "video") {
            videoLoader.item.start(root.videoPath, root.fadeDuration)
          }
        }
      }
    }
  }
}
