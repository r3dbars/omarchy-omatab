import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The "~" in the bar. Click opens the panel; right-click pauses or resumes
// suggestions without opening anything.
BarWidget {
  id: root
  moduleName: "r3dbars.omatab"

  readonly property string controlPath: Quickshell.env("HOME") + "/.local/bin/omatab"
  property bool installed: false
  property bool suggesting: false
  property bool ready: false
  property bool settingUp: false
  property bool actionBusy: false

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
    try {
      var status = JSON.parse(raw)
      root.installed = status.installed === true
      root.suggesting = status.enabled === true && status.service === "active"
      root.ready = status.model_loaded === true
      root.settingUp = !!(status.setup && status.setup.running === true)
    } catch (error) {
      root.installed = false
      root.suggesting = false
      root.ready = false
      root.settingUp = false
    }
  }

  function tooltip() {
    if (root.settingUp) return "Oma Tab is setting up…"
    if (!root.installed) return "Oma Tab is not installed · click to install"
    if (!root.suggesting) return "Oma Tab is paused · right-click to resume"
    if (!root.ready) return "Oma Tab is on · model warming up"
    return "Oma Tab is on · right-click to pause"
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
    text: "~"
    fontSize: Style.font.title
    active: root.installed && root.suggesting
    dimmed: !root.installed || !root.ready
    tooltipText: root.tooltip()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.quickToggle()
      else root.toggle()
    }
  }

  Process {
    id: statusProcess
    command: [root.controlPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: toggleProcess
    command: [root.controlPath, "toggle"]
    onExited: function() {
      root.actionBusy = false
      root.refresh()
    }
  }

  Timer {
    interval: root.settingUp ? 2000 : 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }
}
