import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Three states, top to bottom: not installed (one button), setting up
// (progress line), and ready (switch, keys, two settings, model, numbers).
Panel {
  id: root
  moduleName: "r3dbars.omatab"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property string controlPath: Quickshell.env("HOME") + "/.local/bin/omatab"
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omatab"
  readonly property string installerPath: String(Qt.resolvedUrl("install.sh")).replace(/^file:\/\//, "")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var status: ({})
  property bool loading: false
  property bool actionBusy: false
  property string message: ""
  property string selectedModelId: ""
  property string actionOutput: ""
  property string actionError: ""

  readonly property bool installed: status.installed === true
  readonly property bool enabled: status.enabled === true
  readonly property bool serviceUp: status.service === "active"
  readonly property bool modelLoaded: status.model_loaded === true
  readonly property var setup: status.setup || null
  readonly property bool settingUp: !!(setup && setup.running === true)
  readonly property bool setupFailed: !!(setup && setup.stage === "failed" && !settingUp)
  readonly property var settings: status.settings || ({})
  readonly property var telemetry: status.telemetry || ({})
  readonly property var latency: telemetry.latency_ms || ({})
  readonly property bool hasNumbers: Number(telemetry.shown_count || 0) > 0
  readonly property var availableModels: status.models || []
  readonly property var selectedModel: modelById(selectedModelId)
  readonly property var modelOptions: {
    var options = []
    for (var i = 0; i < availableModels.length; i++)
      options.push({ value: availableModels[i].id, label: availableModels[i].label })
    return options
  }

  function modelById(id) {
    for (var i = 0; i < availableModels.length; i++)
      if (availableModels[i].id === id) return availableModels[i]
    return ({})
  }

  function formatBytes(value) {
    var bytes = Number(value || 0)
    if (!(bytes > 0)) return "—"
    return (bytes / 1000000000).toFixed(1) + " GB"
  }

  function percent(value) {
    var number = Number(value)
    if (!isFinite(number)) return "—"
    return Math.round(number * 100) + "%"
  }

  // Fcitx key names as a person would say them.
  function friendlyKey(name) {
    var names = {
      "grave": "`", "asciitilde": "~", "Tab": "Tab", "Shift+Tab": "Shift+Tab",
      "Control+space": "Ctrl+Space", "Return": "Enter", "space": "Space",
      "Escape": "Esc", "Right": "→", "End": "End"
    }
    var key = String(name || "")
    if (names[key] !== undefined) return names[key]
    return key.replace("Control+", "Ctrl+").replace("Alt+", "Alt+")
  }

  function fullAcceptKeys() {
    var keys = settings.full_accept_keys || []
    if (keys.length === 0) return "Shift+Tab"
    var names = []
    for (var i = 0; i < keys.length; i++) names.push(friendlyKey(keys[i]))
    return names.join(" or ")
  }

  function headline() {
    if (settingUp) return "Setting up…"
    if (!installed) return "Not installed yet"
    if (!serviceUp) return "Input service is not running"
    if (!enabled) return "Paused"
    if (!modelLoaded) return "On · model warming up"
    return "On · suggesting as you type"
  }

  function refresh() {
    if (statusProcess.running) return
    loading = true
    statusProcess.running = true
  }

  function runAction(args, busyMessage) {
    if (actionBusy) return
    actionBusy = true
    actionOutput = ""
    actionError = ""
    message = busyMessage || ""
    actionProcess.command = [root.controlPath].concat(args)
    actionProcess.running = true
  }

  function runModelAction() {
    if (actionBusy || !selectedModel.id || selectedModel.current) return
    runAction(["model", selectedModel.installed ? "use" : "install", selectedModel.id],
      selectedModel.installed ? "Switching model…" :
        "Downloading " + selectedModel.download_gb + " GB, then testing it…")
  }

  function runInstaller() {
    if (installProcess.running) return
    message = "Opening a terminal for setup…"
    installProcess.running = true
    setupRefresh.restart()
  }

  function finalLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines.length > 0 ? lines[lines.length - 1] : ""
  }

  function openDemo() { if (!demoProcess.running) demoProcess.running = true }
  function openLogs() { if (!openLogsProcess.running) openLogsProcess.running = true }

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: modelDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === " " && root.installed) root.runAction([root.enabled ? "disable" : "enable"])
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: "Oma Tab"
            meta: root.headline()
            detail: !root.installed ? "" : root.modelLoaded ? "READY" : "COLD"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.installed && root.enabled ? 1.0 : 0.45
            iconComponent: Component {
              Text {
                text: "⇥"
                color: root.installed && root.enabled ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                font.bold: true
              }
            }
            trailingControl: root.installed ? enableSwitch : null
          }

          // ---- setting up / not installed ----

          Column {
            visible: root.settingUp || root.setupFailed
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: root.setup ? String(root.setup.detail || "") : ""
              textFormat: Text.PlainText
              color: root.setupFailed ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.settingUp
              width: parent.width
              text: "Watch the terminal window for details. This panel updates as setup moves along."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              visible: root.setupFailed
              width: parent.width
              text: "Try setup again"
              bordered: true
              focusable: true
              onClicked: root.runInstaller()
            }
          }

          Column {
            visible: !root.installed && !root.settingUp && !root.setupFailed
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "Oma Tab suggests the next few words as you type, in every app. Press Tab to take a word. Everything runs on this computer and nothing you type leaves it."
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Button {
              width: parent.width
              text: "Install Oma Tab"
              bordered: true
              focusable: true
              onClicked: root.runInstaller()
            }

            Text {
              width: parent.width
              text: "Opens a terminal you can watch. Installs Ollama and a few packages, builds Oma Tab, and downloads a model sized to your GPU (2 to 4 GB). A few minutes."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Text {
            visible: root.message !== "" && !root.settingUp
            width: parent.width
            text: root.message
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // ---- ready ----

          Column {
            visible: root.installed
            width: parent.width
            spacing: Style.space(14)

            PanelSeparator { foreground: root.foreground }

            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "HOW IT WORKS"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                width: parent.width
                text: "Type, pause for a beat, and a grey suggestion appears."
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              InfoRow { label: "Take one word"; value: "Tab" }
              InfoRow { label: "Take it all"; value: root.fullAcceptKeys() }
              InfoRow { label: "Ignore it"; value: "Just keep typing" }
            }

            PanelSeparator { foreground: root.foreground }

            Column {
              width: parent.width
              spacing: Style.space(8)

              Toggle {
                width: parent.width
                label: "Read the screen"
                description: "Looks at what is on screen, like the message you are answering, so replies fit. Stays on this computer."
                checked: root.settings.ocr === true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.runAction(["ocr", root.settings.ocr === true ? "off" : "on"])
              }

              Toggle {
                width: parent.width
                label: "Keep a private log"
                description: "Records suggestions and what you did with them, locally, so you can see what works."
                checked: root.settings.telemetry === true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.runAction(["telemetry", root.settings.telemetry === true ? "off" : "on"])
              }
            }

            PanelSeparator { foreground: root.foreground }

            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "MODEL"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Dropdown {
                id: modelDropdown
                width: parent.width
                label: "Completion model"
                value: root.selectedModelId
                options: root.modelOptions
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(value) { root.selectedModelId = value }
              }

              Text {
                width: parent.width
                text: String(root.selectedModel.description || "Choose a supported local model.")
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              InfoRow { label: "Download"; value: root.selectedModel.download_gb ? root.selectedModel.download_gb + " GB" : "—" }
              InfoRow { label: "GPU memory in use"; value: root.formatBytes(root.status.model_vram_bytes) }

              Text {
                visible: root.selectedModel.requires_terms === true
                width: parent.width
                text: "Gemma requires accepting Google’s model terms on Hugging Face before downloading."
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  visible: root.selectedModel.requires_terms === true
                  width: (parent.width - parent.spacing) * 0.42
                  text: "Review terms"
                  bordered: true
                  focusable: true
                  onClicked: if (!modelTermsProcess.running) modelTermsProcess.running = true
                }

                Button {
                  width: root.selectedModel.requires_terms === true
                    ? (parent.width - parent.spacing) * 0.58 : parent.width
                  text: root.selectedModel.current ? "Current model" :
                    root.selectedModel.installed ? "Use this model" : "Download & use"
                  bordered: true
                  focusable: true
                  enabled: !root.actionBusy && !root.selectedModel.current && !!root.selectedModel.id
                  onClicked: root.runModelAction()
                }
              }
            }

            PanelSeparator {
              visible: root.hasNumbers
              foreground: root.foreground
            }

            Column {
              visible: root.hasNumbers
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "HOW IT IS GOING"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Metric {
                  width: (parent.width - parent.spacing * 2) / 3
                  value: root.latency.p50 == null ? "—" : Math.round(Number(root.latency.p50)) + " ms"
                  label: "TO APPEAR"
                }
                Metric {
                  width: (parent.width - parent.spacing * 2) / 3
                  value: String(root.telemetry.shown_count == null ? "—" : root.telemetry.shown_count)
                  label: "SHOWN"
                }
                Metric {
                  width: (parent.width - parent.spacing * 2) / 3
                  value: root.percent(root.telemetry.acceptance_rate)
                  label: "TAKEN"
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Try it in a demo"
                bordered: true
                focusable: true
                onClicked: root.openDemo()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Restart"
                bordered: true
                focusable: true
                enabled: !root.actionBusy
                onClicked: root.runAction(["restart"], "Restarting…")
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Update Oma Tab"
                bordered: true
                focusable: true
                enabled: !root.settingUp
                onClicked: root.runInstaller()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.settings.telemetry === true ? "Open the log" : (root.loading ? "Refreshing…" : "Refresh")
                bordered: true
                focusable: true
                enabled: !root.loading
                onClicked: root.settings.telemetry === true ? root.openLogs() : root.refresh()
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: enableSwitch
    ToggleSwitch {
      checked: root.enabled
      busy: root.actionBusy
      foreground: root.foreground
      accent: root.accent
      onToggled: root.runAction([root.enabled ? "disable" : "enable"])
    }
  }

  component InfoRow: Row {
    property string label: ""
    property string value: ""
    width: parent ? parent.width : implicitWidth
    spacing: Style.space(12)

    Text {
      width: parent.width * 0.42
      text: parent.label
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      width: parent.width * 0.58 - parent.spacing
      text: parent.value
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideMiddle
    }
  }

  component Metric: Rectangle {
    property string value: "—"
    property string label: ""
    implicitHeight: metricColumn.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.09)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)

    Column {
      id: metricColumn
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: parent.parent.value
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: parent.parent.label
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  Process {
    id: statusProcess
    command: [root.controlPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.status = JSON.parse(text)
          if (root.selectedModelId === "" || root.selectedModelId === "custom")
            root.selectedModelId = String(root.status.model_id || "")
          if (!root.actionBusy) root.message = ""
        } catch (error) {
          root.status = ({})
          root.message = ""
        }
        root.loading = false
      }
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      // No CLI at all means Oma Tab was never installed; the panel shows the
      // install state rather than an error.
      if (exitCode !== 0 && !root.installed) root.loading = false
    }
  }

  Process {
    id: actionProcess
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionOutput = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionError = text
    }
    onExited: function(exitCode) {
      root.actionBusy = false
      var detail = root.finalLine(exitCode === 0 ? root.actionOutput : root.actionError)
      root.message = exitCode === 0 ? "" : (detail !== "" ? detail : "That did not work.")
      actionRefresh.restart()
    }
  }

  Process {
    id: installProcess
    command: ["omarchy-launch-floating-terminal-with-presentation", root.installerPath]
  }

  Process {
    id: demoProcess
    command: ["setsid", "-f", root.controlPath, "demo"]
  }

  Process {
    id: openLogsProcess
    command: ["xdg-open", root.statePath]
  }

  Process {
    id: modelTermsProcess
    command: ["xdg-open", "https://huggingface.co/google/gemma-3-4b-pt-qat-q4_0-gguf"]
  }

  Timer {
    id: actionRefresh
    interval: 450
    repeat: false
    onTriggered: {
      root.refresh()
      if (root.hostWidget && typeof root.hostWidget.refresh === "function") root.hostWidget.refresh()
    }
  }

  Timer {
    id: setupRefresh
    interval: 1500
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: root.settingUp ? 2000 : 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }
}
