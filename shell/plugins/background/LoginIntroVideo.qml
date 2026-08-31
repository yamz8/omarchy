import QtMultimedia
import QtQuick
import qs.Commons

Item {
  id: root

  property string videoPath: ""
  property int fadeDuration: 450
  property int startSerial: 0
  property bool ready: false

  signal fadeRequested(string reason)

  function start(path, fadeMs) {
    videoPath = String(path || "").trim()
    fadeDuration = fadeMs
    ready = false
    startSerial += 1
    player.stop()

    var serial = startSerial
    Qt.callLater(function() {
      if (serial === root.startSerial && root.videoPath) player.play()
    })
  }

  VideoOutput {
    id: videoOutput
    anchors.fill: parent
    visible: root.ready
    fillMode: VideoOutput.PreserveAspectCrop
    endOfStreamPolicy: VideoOutput.KeepLastFrame
  }

  MediaPlayer {
    id: player
    source: root.videoPath ? Util.fileUrl(root.videoPath) : ""
    loops: 1
    videoOutput: videoOutput
    audioOutput: AudioOutput { muted: true }

    onPositionChanged: function() {
      root.ready = true
      if (player.duration <= 0) return
      if (player.position >= Math.max(0, player.duration - root.fadeDuration)) root.fadeRequested("completed")
    }

    onMediaStatusChanged: function() {
      if (player.mediaStatus === MediaPlayer.EndOfMedia) root.fadeRequested("completed")
      else if (player.mediaStatus === MediaPlayer.InvalidMedia) root.fadeRequested("error")
    }

    onErrorOccurred: function() {
      root.fadeRequested("error")
    }
  }

  Component.onDestruction: player.stop()
}
