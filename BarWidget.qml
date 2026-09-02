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
    try {
      root.status = JSON.parse(raw)
    } catch (error) {
      // Keep the last good state; an empty read means the CLI is missing.
      if (raw.trim() === "") root.status = ({})
    }
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
    command: [root.controlPath, "status", "--json", "--brief"]
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
    interval: root.settingUp ? 2000 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }
}
