import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "r3dbars.tilde"

  readonly property string controlPath: Quickshell.env("HOME") + "/.local/bin/tilde-control"
  property bool tildeEnabled: false
  property bool modelLoaded: false

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

  function applyStatus(raw) {
    try {
      var status = JSON.parse(raw)
      root.tildeEnabled = status.enabled === true
      root.modelLoaded = status.model_loaded === true
    } catch (error) {
      root.tildeEnabled = false
      root.modelLoaded = false
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
    active: root.tildeEnabled
    dimmed: !root.modelLoaded
    tooltipText: root.tildeEnabled ? "Tilde is on" : "Tilde is off"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
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
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }
}
