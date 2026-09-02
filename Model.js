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

// ---- bounded stream reading ----
// Helper output is read one chunk at a time and counted as it arrives, so
// the ceiling limits what the process can write, not just what is kept.
// Crossing it discards the read and tells the caller to stop the process,
// which kills the whole helper process group at that moment.

var MAX_ACTION_BYTES = 4096
var MAX_STDERR_BYTES = 4096

// Bytes this text occupies as UTF-8, without encoding a copy of it.
function utf8Length(text) {
  var bytes = 0
  for (var i = 0; i < text.length; i++) {
    var code = text.charCodeAt(i)
    if (code < 0x80) bytes += 1
    else if (code < 0x800) bytes += 2
    else if (code >= 0xd800 && code <= 0xdbff) { bytes += 4; i += 1 }
    else bytes += 3
  }
  return bytes
}

// The command a widget actually runs. The timeout wrapper stays the direct
// child, so stopping the process still signals the whole group, and the
// helper writes through head, which stops it at the ceiling before its bytes
// ever reach the widget. The reader below enforces the same ceilings a second
// time on whatever does arrive.
function boundedCommand(seconds, killAfter, controlPath, args, stdoutLimit) {
  var script = 'set -o pipefail; "$@" 2> >(head -c ' + MAX_STDERR_BYTES +
    ' >&2) | head -c ' + stdoutLimit
  return ["timeout", "--kill-after=" + killAfter, String(seconds),
          "bash", "-c", script, "bash", String(controlPath)].concat(args || [])
}

function newReader(limitBytes) {
  return { limit: limitBytes, bytes: 0, overflow: false, parts: [] }
}

// Returns false once the ceiling is crossed. The caller must then stop the
// process; nothing at or past the ceiling is kept.
function readerPush(reader, chunk) {
  if (!reader || reader.overflow) return false
  var text = (chunk === undefined || chunk === null) ? "" : String(chunk)
  reader.bytes += utf8Length(text)
  if (reader.bytes > reader.limit) {
    reader.overflow = true
    reader.parts = []
    return false
  }
  reader.parts.push(text)
  return true
}

function readerText(reader) {
  if (!reader || reader.overflow) return ""
  return reader.parts.join("")
}

// ---- bounded status parsing ----
// The status JSON comes from a helper process. Only whitelisted fields are
// copied out, every string is truncated, every list is capped, and input
// larger than MAX_STATUS_BYTES is rejected outright, so nothing unbounded
// ever reaches a long-lived QML model.

var MAX_STATUS_BYTES = 262144
var MAX_MODELS = 24
var MAX_KEYS = 8
var SHORT = 64
var LONG = 240

function str(value, max) {
  if (value === undefined || value === null) return ""
  var text = String(value)
  return text.length > max ? text.slice(0, max) : text
}

function num(value) {
  var number = Number(value)
  return isFinite(number) ? number : null
}

function bool(value) { return value === true }

function parseModel(raw) {
  var m = raw || {}
  return {
    id: str(m.id, SHORT),
    label: str(m.label, SHORT),
    description: str(m.description, LONG),
    download_gb: num(m.download_gb),
    installed: bool(m.installed),
    current: bool(m.current),
    requires_terms: bool(m.requires_terms)
  }
}

// Returns a bounded status object, or null when the text is empty, too
// large, or not JSON.
function parseStatus(raw) {
  var text = String(raw || "")
  if (text.length === 0 || text.length > MAX_STATUS_BYTES) return null
  var data
  try { data = JSON.parse(text) } catch (error) { return null }
  if (!data || typeof data !== "object") return null

  var settings = data.settings && typeof data.settings === "object" ? data.settings : {}
  var keys = []
  var rawKeys = Array.isArray(settings.full_accept_keys) ? settings.full_accept_keys : []
  for (var k = 0; k < rawKeys.length && k < MAX_KEYS; k++) keys.push(str(rawKeys[k], SHORT))

  var models = []
  var rawModels = Array.isArray(data.models) ? data.models : []
  for (var i = 0; i < rawModels.length && i < MAX_MODELS; i++) models.push(parseModel(rawModels[i]))

  var telemetry = data.telemetry && typeof data.telemetry === "object" ? data.telemetry : {}
  var latency = telemetry.latency_ms && typeof telemetry.latency_ms === "object" ? telemetry.latency_ms : {}
  var setup = data.setup && typeof data.setup === "object" ? {
    stage: str(data.setup.stage, SHORT),
    detail: str(data.setup.detail, LONG),
    running: bool(data.setup.running)
  } : null

  return {
    installed: bool(data.installed),
    enabled: bool(data.enabled),
    service: str(data.service, SHORT),
    model_loaded: bool(data.model_loaded),
    model_id: str(data.model_id, SHORT),
    model_vram_bytes: num(data.model_vram_bytes),
    models: models,
    settings: {
      ocr: bool(settings.ocr),
      telemetry: bool(settings.telemetry),
      full_accept_keys: keys
    },
    telemetry: {
      shown_count: num(telemetry.shown_count),
      acceptance_rate: num(telemetry.acceptance_rate),
      latency_ms: { p50: num(latency.p50) }
    },
    setup: setup
  }
}
