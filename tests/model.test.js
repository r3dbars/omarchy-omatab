// Run with: node --test tests/
// Loads Model.js the way the QML engine would see it: as a plain script
// with no module system, after dropping the .pragma line.
var test = require("node:test")
var assert = require("node:assert/strict")
var fs = require("node:fs")
var path = require("node:path")
var vm = require("node:vm")

function loadModel() {
  var source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  var lines = source.split("\n").filter(function(line) { return line.indexOf(".pragma") !== 0 })
  var context = {}
  vm.createContext(context)
  vm.runInContext(lines.join("\n"), context)
  return context
}

var Model = loadModel()

// Objects built inside the sandbox have another realm's prototypes, so
// compare them by value.
function plain(value) { return JSON.parse(JSON.stringify(value)) }

test("Model.js stays QML-engine compatible", function() {
  var source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  assert.equal(source.indexOf(".pragma library"), 0)
  assert.doesNotMatch(source, /\b(const|let)\s/, "no const or let")
  assert.doesNotMatch(source, /=>/, "no arrow functions")
  assert.doesNotMatch(source.replace(/"`"/g, ""), /`/, "no template literals")
})

test("friendlyKey names keys the way people say them", function() {
  assert.equal(Model.friendlyKey("grave"), "`")
  assert.equal(Model.friendlyKey("asciitilde"), "~")
  assert.equal(Model.friendlyKey("Shift+Tab"), "Shift+Tab")
  assert.equal(Model.friendlyKey("Control+Right"), "Ctrl+Right")
  assert.equal(Model.friendlyKey(undefined), "")
})

test("fullAcceptKeys joins several keys and falls back to Shift+Tab", function() {
  assert.equal(Model.fullAcceptKeys({ full_accept_keys: ["grave", "asciitilde"] }), "` or ~")
  assert.equal(Model.fullAcceptKeys({ full_accept_keys: [] }), "Shift+Tab")
  assert.equal(Model.fullAcceptKeys(undefined), "Shift+Tab")
})

test("headline follows the state ladder", function() {
  assert.equal(Model.headline({}), "Not installed yet")
  assert.equal(Model.headline({ setup: { running: true } }), "Setting up…")
  assert.equal(Model.headline({ installed: true, service: "failed" }), "Input service is not running")
  assert.equal(Model.headline({ installed: true, service: "active", enabled: false }), "Paused")
  assert.equal(Model.headline({ installed: true, service: "active", enabled: true, model_loaded: false }), "On · model warming up")
  assert.equal(Model.headline({ installed: true, service: "active", enabled: true, model_loaded: true }), "On · suggesting as you type")
})

test("tooltip mirrors the headline with the right-click hint", function() {
  assert.equal(Model.tooltip({}), "Oma Tab is not installed · click to install")
  assert.equal(Model.tooltip({ installed: true, service: "active", enabled: false }), "Oma Tab is paused · right-click to resume")
  assert.equal(Model.tooltip({ installed: true, service: "active", enabled: true, model_loaded: true }), "Oma Tab is on · right-click to pause")
})

test("formatting helpers handle missing values", function() {
  assert.equal(Model.formatBytes(9218482502), "9.2 GB")
  assert.equal(Model.formatBytes(null), "—")
  assert.equal(Model.percent(0.1246), "12%")
  assert.equal(Model.percent(null), "—")
  assert.equal(Model.finalLine("a\nb\n"), "b")
  assert.equal(Model.finalLine(""), "")
  assert.equal(Model.pathFromUrl("file:///home/me/x/install.sh"), "/home/me/x/install.sh")
})

test("model helpers build dropdown options and look up by id", function() {
  var models = [{ id: "a", label: "A" }, { id: "b", label: "B" }]
  assert.deepEqual(plain(Model.modelOptions(models)), [{ value: "a", label: "A" }, { value: "b", label: "B" }])
  assert.deepEqual(plain(Model.modelById(models, "b")), { id: "b", label: "B" })
  assert.deepEqual(plain(Model.modelById(models, "zzz")), {})
  assert.deepEqual(plain(Model.modelOptions(undefined)), [])
})

test("parseStatus whitelists, truncates, and caps", function() {
  var big = new Array(400).join("x")
  var models = []
  for (var i = 0; i < 100; i++) models.push({ id: "m" + i, label: big, evil: "no" })
  var raw = JSON.stringify({
    installed: true, enabled: "yes", service: "active", model_loaded: true,
    model_id: big, extra: { deep: true },
    models: models,
    settings: { ocr: true, telemetry: 1, full_accept_keys: new Array(50).join("k ").split(" ") },
    telemetry: { shown_count: "12", acceptance_rate: 0.25, latency_ms: { p50: 74.2 } },
    setup: { stage: "model", detail: big, running: true, pid: 5 }
  })
  var status = plain(Model.parseStatus(raw))
  assert.equal(status.installed, true)
  assert.equal(status.enabled, false, "non-boolean enabled is false")
  assert.equal(status.model_id.length, 64)
  assert.equal(status.extra, undefined, "unknown fields dropped")
  assert.equal(status.models.length, 24)
  assert.equal(status.models[0].label.length, 64)
  assert.equal(status.models[0].evil, undefined)
  assert.equal(status.settings.telemetry, false)
  assert.equal(status.settings.full_accept_keys.length, 8)
  assert.equal(status.telemetry.shown_count, 12)
  assert.equal(status.telemetry.latency_ms.p50, 74.2)
  assert.equal(status.setup.detail.length, 240)
  assert.equal(status.setup.running, true)
  assert.equal(status.setup.pid, undefined)
})

test("parseStatus rejects empty, oversized, and non-JSON input", function() {
  assert.equal(Model.parseStatus(""), null)
  assert.equal(Model.parseStatus("not json"), null)
  assert.equal(Model.parseStatus("[1,2]") === null, false, "arrays are objects; fields default")
  assert.equal(Model.parseStatus("null"), null)
  assert.equal(Model.parseStatus(new Array(262146).join("{")), null)
  var ok = Model.parseStatus("{}")
  assert.equal(ok.installed, false)
  assert.equal(ok.models.length, 0)
  assert.equal(ok.setup, null)
})
