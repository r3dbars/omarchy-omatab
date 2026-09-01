import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "r3dbars.tilde"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property string controlPath: Quickshell.env("HOME") + "/.local/bin/tilde-control"
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/tilde"
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
  readonly property bool modelLoaded: status.model_loaded === true
  readonly property var telemetry: status.telemetry || ({})
  readonly property var latency: telemetry.latency_ms || ({})
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

  function shortModel(value) {
    var model = String(value || "Not configured")
    var slash = model.lastIndexOf("/")
    return slash >= 0 ? model.slice(slash + 1) : model
  }

  function refresh() {
    if (statusProcess.running) return
    loading = true
    statusProcess.running = true
  }

  function runAction(action) {
    if (actionBusy) return
    actionBusy = true
    message = action === "restart" ? "Restarting Tilde…" :
      action === "warm" ? "Warming model…" : "Updating…"
    actionProcess.command = [root.controlPath, action]
    actionProcess.running = true
  }

  function runModelAction() {
    if (actionBusy || !selectedModel.id || selectedModel.current) return
    actionBusy = true
    actionOutput = ""
    actionError = ""
    message = selectedModel.installed ? "Switching model…" :
      "Downloading " + selectedModel.download_gb + " GB, then testing it…"
    actionProcess.command = [root.controlPath, "model",
      selectedModel.installed ? "use" : "install", selectedModel.id]
    actionProcess.running = true
  }

  function finalLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines.length > 0 ? lines[lines.length - 1] : ""
  }

  function openLogs() {
    if (!openLogsProcess.running) openLogsProcess.running = true
  }

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
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: modelDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "w" || text === "W") root.runAction("warm")
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
            title: "Tilde"
            meta: !root.installed ? "Engine not installed" :
              root.enabled ? "Autocomplete is on" : "Autocomplete is off"
            detail: root.modelLoaded ? "READY" : "COLD"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.enabled ? 1.0 : 0.45
            iconComponent: Component {
              Text {
                text: "~"
                color: root.enabled ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                font.bold: true
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                checked: root.enabled
                busy: root.actionBusy
                foreground: root.foreground
                accent: root.accent
                onToggled: root.runAction(root.enabled ? "disable" : "enable")
              }
            }
          }

          Text {
            visible: root.message !== ""
            width: parent.width
            text: root.message
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
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
            InfoRow { label: "Completion"; value: root.selectedModel.fim ? "Cursor-aware FIM" : "Natural continuation" }
            InfoRow { label: "GPU memory"; value: root.formatBytes(root.status.model_vram_bytes) }
            InfoRow { label: "Context"; value: String(root.status.context_length || "—") + (root.status.context_length ? " tokens" : "") }
            InfoRow { label: "Warmup"; value: root.status.warm_timer === "active" ? "Always ready" : "Not running" }

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
                  root.selectedModel.installed ? "Use model" : "Download & use"
                bordered: true
                focusable: true
                enabled: !root.actionBusy && !root.selectedModel.current && !!root.selectedModel.id
                onClicked: root.runModelAction()
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "HOW IT FEELS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Metric {
                width: (parent.width - parent.spacing * 2) / 3
                value: root.latency.p50 == null ? "—" : Math.round(Number(root.latency.p50)) + " ms"
                label: "MEDIAN"
              }
              Metric {
                width: (parent.width - parent.spacing * 2) / 3
                value: String(root.telemetry.shown_count == null ? "—" : root.telemetry.shown_count)
                label: "SHOWN"
              }
              Metric {
                width: (parent.width - parent.spacing * 2) / 3
                value: root.percent(root.telemetry.acceptance_rate)
                label: "ACCEPTED"
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "CONTEXT & PRIVACY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            InfoRow { label: "Writing context"; value: "Textbox + visible window" }
            InfoRow { label: "Input method"; value: String(root.status.input_method || "Not selected") }
            InfoRow { label: "Inference"; value: "Local Ollama" }
            InfoRow { label: "Telemetry"; value: root.status.telemetry_enabled ? "Private · local only" : "Off" }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Warm model"
              bordered: true
              focusable: true
              enabled: !root.actionBusy
              onClicked: root.runAction("warm")
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Restart Tilde"
              bordered: true
              focusable: true
              enabled: !root.actionBusy
              onClicked: root.runAction("restart")
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Open local logs"
              bordered: true
              focusable: true
              onClicked: root.openLogs()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: root.loading ? "Refreshing…" : "Refresh"
              bordered: true
              focusable: true
              enabled: !root.loading
              onClicked: root.refresh()
            }
          }

          Text {
            width: parent.width
            text: "Downloads are verified and warmed before Tilde switches models. Your current model stays active if setup fails."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component InfoRow: Row {
    property string label: ""
    property string value: ""
    width: parent ? parent.width : implicitWidth
    spacing: Style.space(12)

    Text {
      width: parent.width * 0.38
      text: parent.label
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      width: parent.width * 0.62 - parent.spacing
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
          root.message = "Could not read Tilde status."
        }
        root.loading = false
      }
    }
    stderr: StdioCollector { waitForEnd: true }
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
      root.message = detail !== "" ? detail : (exitCode === 0 ? "Done." : "That action failed.")
      actionRefresh.restart()
    }
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
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }
}
