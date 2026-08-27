import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
  property string eventsPath: runtimeDirectory + "/onedrive-eag-erolleman/events.jsonl"
  property string activeState: "unknown"
  property string subState: ""
  property string result: ""
  property string syncState: ""
  property string statusText: "Waiting for OneDrive service"
  property string lastError: ""
  property var transfers: []

  readonly property bool online: activeState === "active"
  readonly property bool failed: activeState === "failed" || (result !== "" && result !== "success")
  readonly property string iconStatus: failed ? "failed"
    : (!online ? "offline"
       : ((syncState === "syncing" || syncState === "processing" || syncState === "initializing") ? "syncing" : "online"))
  readonly property string serviceText: failed ? "Service failed"
    : (online ? "Service online" : "Service offline")

  function applyEvents(raw) {
    var snapshot = Model.eventSnapshot(Model.parseJsonl(raw))
    syncState = String(snapshot.syncState || "")
    statusText = String(snapshot.statusText || "Waiting for sync activity")
    lastError = String(snapshot.lastError || "")
    transfers = snapshot.transfers || []
  }

  function applyUnitStatus(raw) {
    var next = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var index = lines[i].indexOf("=")
      if (index > 0) next[lines[i].slice(0, index)] = lines[i].slice(index + 1)
    }
    activeState = String(next.ActiveState || "unknown")
    subState = String(next.SubState || "")
    result = String(next.Result || "")
  }

  function refresh() {
    eventsFile.reload()
    if (!serviceStatus.running) serviceStatus.running = true
  }

  FileView {
    id: eventsFile
    path: root.eventsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyEvents(text())
    onLoadFailed: root.applyEvents("")
    onFileChanged: reload()
  }

  Process {
    id: serviceStatus
    command: [
      "systemctl", "--user", "show", "onedrive-eag-erolleman.service",
      "--property=ActiveState,SubState,Result", "--no-pager"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyUnitStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.activeState = "unknown"
        root.result = "failed"
      }
    }
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
