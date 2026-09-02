import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The "~" in the bar. Click opens the panel; right-click pauses or resumes
// suggestions without opening anything.
BarWidget {
  id: root
  moduleName: "r3dbars.omatab"

  readonly property string controlPath: Quickshell.env("HOME") + "/.local/bin/omatab"
  property var status: ({})
  property bool actionBusy: false
  readonly property bool installed: status.installed === true
  readonly property bool suggesting: status.enabled === true && status.service === "active"
  readonly property bool ready: status.model_loaded === true
  readonly property bool settingUp: !!(status.setup && status.setup.running === true)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (panelLoader.item) panelLoader.item.refresh()
  }

  function quickToggle() {
    if (!root.installed || root.actionBusy) { root.open(); return }
    root.actionBusy = true
    toggleProcess.running = true
  }

  function applyStatus(raw) {
    // Only whitelisted, size-bounded fields come out of the helper's JSON.
    var parsed = Model.parseStatus(raw)
    if (parsed) root.status = parsed
    else if (String(raw).trim() === "") root.status = ({})
    // Otherwise keep the last good state.
  }

  Component.onDestruction: {
    statusProcess.running = false
    toggleProcess.running = false
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "⇥"
    fontSize: Style.font.title
    active: root.installed && root.suggesting
    dimmed: !root.installed || !root.ready
    tooltipText: Model.tooltip(root.status)
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.quickToggle()
      else root.toggle()
    }
  }

  Process {
    id: statusProcess
    // --brief skips the quality report, so this poll costs a few
    // milliseconds instead of half a second.
    // `timeout` gives the helper a deadline and kills its whole process
    // group if it hangs, so a stuck poll can never wedge the widget.
    command: Model.boundedCommand(8, 2, root.controlPath,
      ["status", "--json", "--brief"], Model.MAX_STATUS_BYTES)
    // A process that never starts produces no output, so the stale-data
    // rule would keep an old "on" forever. No start means no CLI.
    property bool launched: false
    // Both streams are counted as they arrive and capped; see Model.js.
    property var outReader: null
    property var errReader: null
    onStarted: launched = true
    onRunningChanged: {
      if (running) {
        launched = false
        outReader = Model.newReader(Model.MAX_STATUS_BYTES)
        errReader = Model.newReader(Model.MAX_STDERR_BYTES)
      } else if (!launched) {
        root.status = ({})
      }
    }
    // The whole reply is in hand once the helper is gone. An overrun poll
    // leaves the last good status in place; the next tick tries again.
    onExited: if (outReader && !outReader.overflow) root.applyStatus(Model.readerText(outReader))
    stdout: SplitParser {
      // No split marker: every read is delivered as it arrives rather than
      // being buffered until a delimiter or the end of the stream.
      splitMarker: ""
      onRead: function(data) {
        if (!Model.readerPush(statusProcess.outReader, data)) statusProcess.running = false
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) {
        if (!Model.readerPush(statusProcess.errReader, data)) statusProcess.running = false
      }
    }
  }

  Process {
    id: toggleProcess
    command: Model.boundedCommand(15, 2, root.controlPath, ["toggle"], Model.MAX_ACTION_BYTES)
    property var outReader: null
    property var errReader: null
    onRunningChanged: if (running) {
      outReader = Model.newReader(Model.MAX_ACTION_BYTES)
      errReader = Model.newReader(Model.MAX_STDERR_BYTES)
    }
    onExited: function() {
      root.actionBusy = false
      root.refresh()
    }
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(data) {
        if (!Model.readerPush(toggleProcess.outReader, data)) toggleProcess.running = false
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) {
        if (!Model.readerPush(toggleProcess.errReader, data)) toggleProcess.running = false
      }
    }
  }

  Timer {
    // Slow right down when there is nothing to poll yet.
    interval: root.settingUp ? 2000 : (root.installed ? 10000 : 60000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }
}
