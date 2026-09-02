.pragma library

// Pure helpers for the Oma Tab widget and panel. Kept QML-engine friendly:
// var and function only, no const/let, arrows, or template literals.

var KEY_NAMES = {
  "grave": "`",
  "asciitilde": "~",
  "Tab": "Tab",
  "Shift+Tab": "Shift+Tab",
  "Control+space": "Ctrl+Space",
  "Return": "Enter",
  "space": "Space",
  "Escape": "Esc",
  "Right": "→",
  "End": "End"
}

// Fcitx key names as a person would say them.
function friendlyKey(name) {
  var key = String(name || "")
  if (KEY_NAMES[key] !== undefined) return KEY_NAMES[key]
  return key.replace("Control+", "Ctrl+")
}

// "Shift+Tab", or "backtick or ~" spelled out when several keys accept everything.
function fullAcceptKeys(settings) {
  var keys = (settings && settings.full_accept_keys) || []
  if (keys.length === 0) return "Shift+Tab"
  var names = []
  for (var i = 0; i < keys.length; i++) names.push(friendlyKey(keys[i]))
  return names.join(" or ")
}

// One line under the title that says what state Oma Tab is in.
function headline(status) {
  var s = status || {}
  var setup = s.setup || null
  if (setup && setup.running === true) return "Setting up…"
  if (s.installed !== true) return "Not installed yet"
  if (s.service !== "active") return "Input service is not running"
  if (s.enabled !== true) return "Paused"
  if (s.model_loaded !== true) return "On · model warming up"
  return "On · suggesting as you type"
}

// Bar-button tooltip for the same states, with the right-click hint.
function tooltip(status) {
  var s = status || {}
  var setup = s.setup || null
  if (setup && setup.running === true) return "Oma Tab is setting up…"
  if (s.installed !== true) return "Oma Tab is not installed · click to install"
  if (s.enabled !== true || s.service !== "active") return "Oma Tab is paused · right-click to resume"
  if (s.model_loaded !== true) return "Oma Tab is on · model warming up"
  return "Oma Tab is on · right-click to pause"
}

function formatBytes(value) {
  var bytes = Number(value || 0)
  if (!(bytes > 0)) return "—"
  return (bytes / 1000000000).toFixed(1) + " GB"
}

function percent(value) {
  if (value === null || value === undefined) return "—"
  var number = Number(value)
  if (!isFinite(number)) return "—"
  return Math.round(number * 100) + "%"
}

function finalLine(text) {
  var lines = String(text || "").trim().split("\n")
  return lines.length > 0 ? lines[lines.length - 1] : ""
}

// Turns a file:// URL from Qt.resolvedUrl into a plain path.
function pathFromUrl(url) {
  return String(url || "").replace(/^file:\/\//, "")
}

// Dropdown options for the model picker.
function modelOptions(models) {
  var options = []
  var list = models || []
  for (var i = 0; i < list.length; i++)
    options.push({ value: list[i].id, label: list[i].label })
  return options
}

function modelById(models, id) {
  var list = models || []
  for (var i = 0; i < list.length; i++)
    if (list[i].id === id) return list[i]
  return {}
}
