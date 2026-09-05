import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Quattrograph.js" as Curve

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var bar: null
  property var hostWidget: null
  property bool opened: false
  property bool popoutSwitchClosing: false
  property bool applyingStore: false
  property bool writingStore: false
  property bool wandering: false
  property bool wanderHolding: false
  property real holdUntil: 0
  property real penT: 0
  property bool strokeDirty: false
  property int wanderSalt: 0
  property string openSheet: ""

  property real fixedR: 100
  property real rollingR: 25
  property real penP: 40
  property bool epi: false
  property real lineWidth: 3
  property string inkMode: "theme"
  property string strokeKey: "accent"
  property string paper: "inset"
  property real drawSpeed: 0.22
  property bool keepLayers: true
  property var favorites: []
  property var ghosts: []
  property var livePts: []
  property var palette: []
  property real lastPenMs: 0

  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family
  readonly property var presetList: Curve.presets()
  readonly property real penCeiling: Curve.penMax(root.rollingR)
  readonly property color paperColor: root.paper === "lift"
    ? Color.menu.selectedBackground
    : Qt.rgba(0, 0, 0, 0.42)
  readonly property var liveCurve: {
    return {
      fixedR: root.fixedR,
      rollingR: root.rollingR,
      penP: root.penP,
      epi: root.epi
    }
  }
  readonly property string paperName: Curve.lookName(root.liveCurve, root.favorites)

  readonly property var fakeBar: QtObject {
    readonly property color foreground: root.foreground
    readonly property color background: root.background
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: root.fontFamily
    readonly property string position: "top"
    readonly property bool vertical: false
    readonly property int barSize: 26
  }

  function currentLook() {
    return Curve.copyLook({
      fixedR: root.fixedR,
      rollingR: root.rollingR,
      penP: root.penP,
      epi: root.epi,
      lineWidth: root.lineWidth,
      inkMode: root.inkMode,
      strokeKey: root.strokeKey,
      paper: root.paper,
      drawSpeed: root.drawSpeed,
      keepLayers: root.keepLayers
    })
  }

  function applyLook(look, preservePace, fromStore) {
    var next = Curve.copyLook(look)
    var sameCurve = next.fixedR === root.fixedR && next.rollingR === root.rollingR &&
                    next.penP === root.penP && next.epi === root.epi
    root.applyingStore = true
    root.fixedR = next.fixedR
    root.rollingR = next.rollingR
    root.penP = next.penP
    root.epi = next.epi
    root.lineWidth = next.lineWidth
    root.paper = next.paper
    if (!preservePace) {
      root.inkMode = next.inkMode
      root.strokeKey = next.strokeKey
      root.drawSpeed = next.drawSpeed
      root.keepLayers = next.keepLayers
    }
    root.applyingStore = false
    if (sameCurve) {
      if (root.opened)
        canvas.requestPaint()
    } else {
      root.wanderHolding = false
      root.startPen()
    }
    if (!fromStore && !root.wandering)
      persistTimer.restart()
  }

  function persistNow() {
    if (root.applyingStore || root.wandering || root.writingStore)
      return
    root.writingStore = true
    storeFile.setText(Curve.serializeStore({
      last: root.currentLook(),
      favorites: root.favorites
    }))
    Qt.callLater(function() { root.writingStore = false })
  }

  function saveFavorite() {
    if (root.favorites.length >= 12)
      return
    var next = root.favorites.slice()
    next.push({
      id: "fav." + Date.now(),
      name: Curve.nextFavoriteName(root.favorites),
      look: root.currentLook()
    })
    root.favorites = next
    persistNow()
    root.openSheet = "looks"
  }

  function deleteFavorite(id) {
    var next = []
    for (var i = 0; i < root.favorites.length; i++) {
      if (root.favorites[i].id !== id)
        next.push(root.favorites[i])
    }
    root.favorites = next
    persistNow()
  }

  function rebuildLivePts() {
    if (canvas.width < 8 || canvas.height < 8) {
      root.livePts = []
      return
    }
    root.livePts = Curve.pointList(root.fixedR, root.rollingR, root.penP, canvas.width, canvas.height, 0, root.epi)
  }

  function snapshotGhost() {
    if (!root.keepLayers || canvas.width < 8)
      return
    var pts = root.livePts
    if (!pts || pts.length < 2)
      return
    var n = Curve.visibleCount(pts.length, Math.min(1, root.penT))
    if (n < 2)
      return
    var next = root.ghosts.slice()
    next.push({
      pts: Curve.thinPoints(pts.slice(0, n), 280),
      inkMode: root.inkMode,
      lineWidth: root.lineWidth
    })
    if (next.length > 4)
      next.shift()
    root.ghosts = next
  }

  function startPen() {
    if (root.keepLayers && root.penT > 0.04)
      root.snapshotGhost()
    root.penT = 0
    root.lastPenMs = 0
    root.rebuildLivePts()
    if (root.opened)
      penTimer.start()
  }

  function beginStroke() {
    if (root.strokeDirty)
      return
    root.strokeDirty = true
    root.startPen()
  }

  function endStroke() {
    root.strokeDirty = false
  }

  function toggleWander() {
    root.wanderHolding = false
    root.openSheet = ""
    if (root.wandering) {
      root.wandering = false
      persistNow()
      return
    }
    root.wandering = true
    root.startPen()
  }

  function advanceWander() {
    if (!root.wandering || !root.opened)
      return
    root.wanderSalt += 1
    root.applyLook(Curve.nextWanderLook(root.currentLook(), root.wanderSalt), true)
  }

  function toggleSheet(name) {
    root.openSheet = root.openSheet === name ? "" : name
  }

  function hideSheets() {
    root.openSheet = ""
  }

  function open(payloadJson) {
    root.opened = true
    themeColorsFile.reload()
    Qt.callLater(function() {
      if (!root.opened)
        return
      keyCatcher.forceActiveFocus()
      root.startPen()
    })
  }

  function close() {
    if (root.wandering)
      root.wandering = false
    root.wanderHolding = false
    root.openSheet = ""
    penTimer.stop()
    root.opened = false
    persistNow()
  }

  function toggle() {
    if (root.opened)
      dismiss()
    else
      open("{}")
  }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }

  function dismiss() {
    if (root.hostWidget && root.hostWidget.bar && root.hostWidget.bar.shell &&
        typeof root.hostWidget.bar.shell.hide === "function") {
      root.hostWidget.bar.shell.hide("richardb-quattrograph")
      return
    }
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "richardb-quattrograph")
    else
      close()
  }

  function hslStroke(t) {
    var hue = Math.round((t % 1) * 360)
    return "hsl(" + hue + ", 78%, 64%)"
  }

  function colorCss(c) {
    return Qt.hsla(c.hslHue, c.hslSaturation, c.hslLightness, 1)
  }

  onFixedRChanged: { root.rebuildLivePts(); persistTimer.restart() }
  onRollingRChanged: { root.rebuildLivePts(); persistTimer.restart() }
  onPenPChanged: { root.rebuildLivePts(); persistTimer.restart() }
  onEpiChanged: { root.rebuildLivePts(); persistTimer.restart() }
  onLineWidthChanged: { persistTimer.restart(); if (root.opened) canvas.requestPaint() }
  onInkModeChanged: { persistTimer.restart(); if (root.opened) canvas.requestPaint() }
  onStrokeKeyChanged: persistTimer.restart()
  onPaperChanged: persistTimer.restart()
  onDrawSpeedChanged: persistTimer.restart()
  onKeepLayersChanged: {
    if (!root.keepLayers)
      root.ghosts = []
    persistTimer.restart()
    if (root.opened)
      canvas.requestPaint()
  }

  Timer {
    id: persistTimer
    interval: 350
    repeat: false
    onTriggered: root.persistNow()
  }

  Timer {
    id: penTimer
    interval: 16
    repeat: true
    running: root.opened
    onTriggered: {
      var now = Date.now()
      var dt = root.lastPenMs ? Math.min(0.05, (now - root.lastPenMs) / 1000) : 0.016
      root.lastPenMs = now
      var rate = Curve.penRate(root.drawSpeed)
      if (root.wanderHolding) {
        root.penT += dt * rate
        if (now >= root.holdUntil)
          root.advanceWander()
        else
          canvas.requestPaint()
        return
      }
      var before = root.penT
      root.penT += dt * rate
      if (root.wandering && before < 1 && root.penT >= 1) {
        root.penT = 1
        root.wanderHolding = true
        root.holdUntil = now + 1800
      }
      canvas.requestPaint()
    }
  }

  FileView {
    id: storeFile
    path: Quickshell.env("HOME") + "/.config/omarchy/quattrograph.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.writingStore)
        return
      var store = Curve.parseStore(text())
      root.favorites = store.favorites
      if (store.last)
        root.applyLook(store.last, false, true)
    }
    onLoadFailed: {
      root.favorites = []
    }
    onFileChanged: {
      if (root.writingStore)
        return
      reload()
    }
  }

  FileView {
    id: themeColorsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.palette = Curve.themePalette(text())
    onLoadFailed: root.palette = []
    onFileChanged: reload()
  }

  onPaletteChanged: Qt.callLater(function() {
    if (root.opened)
      canvas.requestPaint()
  })

  PanelWindow {
    visible: root.opened
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "richardb-quattrograph"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.72)
      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.openSheet !== "")
            root.hideSheets()
          else
            root.dismiss()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Space) {
          root.toggleWander()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_S) {
          root.saveFavorite()
          event.accepted = true
        }
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(1100), keyCatcher.width - Style.space(32))
        height: Math.min(Style.space(740), keyCatcher.height - Style.space(32))
        color: root.background
        radius: Style.cornerRadius
        border.color: root.border
        border.width: Math.max(1, Style.space(1))
        clip: true

        MouseArea {
          anchors.fill: parent
          onClicked: root.hideSheets()
        }

        Rectangle {
          id: drawBox
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: toolRest.top
          color: root.paperColor
          clip: true

          Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            renderStrategy: Canvas.Immediate

            onWidthChanged: { root.rebuildLivePts(); requestPaint() }
            onHeightChanged: { root.rebuildLivePts(); requestPaint() }

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              ctx.lineJoin = "round"
              ctx.lineCap = "round"

              function strokeColor(mode, t) {
                if (Curve.migrateInk(mode, "path") === "theme") {
                  var mixed = Curve.paletteStroke(root.palette, t)
                  if (mixed)
                    return mixed
                }
                return root.hslStroke(t)
              }

              function strokePoly(pts, n, width, alpha, css) {
                if (!pts || n < 2) return
                ctx.globalAlpha = alpha
                ctx.lineWidth = width
                ctx.strokeStyle = css
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var i = 1; i < n; i++)
                  ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
                ctx.globalAlpha = 1
              }

              function strokeInk(pts, n, mode, width) {
                if (!pts || n < 2) return
                ctx.lineWidth = width
                var segs = Math.min(24, n - 1)
                var stride = Math.max(1, Math.floor((n - 1) / segs))
                for (var s = 0; s < n - 1; s += stride) {
                  var end = Math.min(n - 1, s + stride + 1)
                  ctx.beginPath()
                  ctx.strokeStyle = strokeColor(mode, s / Math.max(1, n - 1))
                  ctx.moveTo(pts[s].x, pts[s].y)
                  for (var j = s + 1; j <= end; j++)
                    ctx.lineTo(pts[j].x, pts[j].y)
                  ctx.stroke()
                }
              }

              var ghosts = root.ghosts
              for (var g = 0; g < ghosts.length; g++) {
                var ghost = ghosts[g]
                var fade = 0.08 + 0.06 * (g / Math.max(1, ghosts.length))
                strokePoly(ghost.pts, ghost.pts.length, ghost.lineWidth, fade,
                           strokeColor(ghost.inkMode, 0.35))
              }

              var pts = root.livePts
              if (!pts || pts.length < 2)
                return
              var n = Curve.visibleCount(pts.length, Math.min(1, root.penT))
              strokeInk(pts, n, root.inkMode, root.lineWidth)

              var tipFrac = root.penT % 1
              if (tipFrac === 0 && root.penT > 0)
                tipFrac = 1
              var tipAt = Curve.visibleCount(pts.length, tipFrac)
              var tip = pts[tipAt - 1]
              ctx.fillStyle = "#ffffff"
              ctx.beginPath()
              ctx.arc(tip.x, tip.y, Math.max(3, root.lineWidth + 1.5), 0, Math.PI * 2)
              ctx.fill()
            }
          }

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(18)
            text: root.paperName + (root.wanderHolding ? "  ·  holding" : "")
            color: root.foreground
            opacity: root.wanderHolding ? 0.62 : 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.letterSpacing: 0.8
          }
        }

        Rectangle {
          id: looksSheet
          visible: root.openSheet === "looks"
          z: 40
          anchors.right: parent.right
          anchors.bottom: toolRest.top
          anchors.margins: Style.space(12)
          width: Style.space(340)
          height: looksCol.implicitHeight + Style.space(28)
          color: root.background
          radius: Style.cornerRadius
          border.color: root.border
          border.width: Math.max(1, Style.space(1))

          MouseArea {
            anchors.fill: parent
            onClicked: {}
          }

          ColumnLayout {
            id: looksCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(14)
            spacing: Style.space(10)

            SectionLabel { text: "Looks" }

            Flow {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: root.presetList
                Button {
                  required property var modelData
                  text: modelData.name
                  selected: Curve.looksClose(modelData.look, root.liveCurve)
                  bordered: true
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.space(4)
                  foreground: root.foreground
                  onClicked: root.applyLook(modelData.look, true)
                }
              }
            }

            SectionLabel { text: "Favorites" }

            Text {
              visible: root.favorites.length === 0
              text: "Nothing saved yet."
              color: root.foreground
              opacity: 0.55
              wrapMode: Text.Wrap
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            Flow {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: root.favorites
                Row {
                  required property var modelData
                  spacing: Style.space(4)
                  Button {
                    text: modelData.name
                    selected: Curve.looksClose(modelData.look, root.liveCurve)
                    bordered: true
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(8)
                    verticalPadding: Style.space(4)
                    foreground: root.foreground
                    onClicked: root.applyLook(modelData.look, false)
                  }
                  Button {
                    text: "×"
                    bordered: true
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(8)
                    verticalPadding: Style.space(4)
                    onClicked: root.deleteFavorite(modelData.id)
                  }
                }
              }
            }
          }
        }

        Rectangle {
          id: inkSheet
          visible: root.openSheet === "ink"
          z: 40
          anchors.right: parent.right
          anchors.bottom: toolRest.top
          anchors.margins: Style.space(12)
          width: Style.space(300)
          height: inkCol.implicitHeight + Style.space(28)
          color: root.background
          radius: Style.cornerRadius
          border.color: root.border
          border.width: Math.max(1, Style.space(1))

          MouseArea {
            anchors.fill: parent
            onClicked: {}
          }

          ColumnLayout {
            id: inkCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(14)
            spacing: Style.space(10)

            SectionLabel { text: "Ink" }

            CompactSlider {
              label: "Width"
              value: root.lineWidth
              minimum: 1
              maximum: 8
              onMoved: function(v) { root.lineWidth = v }
            }

            ChipRow {
              model: [
                { key: "theme", label: "Theme" },
                { key: "path", label: "Rainbow" }
              ]
              currentKey: root.inkMode
              onPicked: function(key) { root.inkMode = key }
            }

            ChipRow {
              model: [
                { key: "inset", label: "Inset" },
                { key: "lift", label: "Lift" }
              ]
              currentKey: root.paper
              onPicked: function(key) { root.paper = key }
            }

            ChipRow {
              model: [
                { key: "wipe", label: "Wipe" },
                { key: "keep", label: "Keep" }
              ]
              currentKey: root.keepLayers ? "keep" : "wipe"
              onPicked: function(key) { root.keepLayers = key === "keep" }
            }
          }
        }

        Rectangle {
          id: toolRest
          z: 30
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: barInner.implicitHeight + Style.space(20)
          color: Qt.rgba(0, 0, 0, 0.28)

          RowLayout {
            id: barInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            spacing: Style.space(12)

            Button {
              text: root.wandering ? "Wandering" : "Wander"
              selected: root.wandering
              bordered: true
              fontSize: Style.font.body
              horizontalPadding: Style.space(14)
              verticalPadding: Style.space(8)
              foreground: root.foreground
              onClicked: root.toggleWander()
            }

            RowLayout {
              id: restRow
              Layout.fillWidth: true
              spacing: Style.space(10)
              opacity: root.wandering ? 0.58 : 1
              Behavior on opacity { NumberAnimation { duration: 220 } }

              Button {
                text: root.favorites.length >= 12 ? "Full" : "Save"
                enabled: root.favorites.length < 12
                bordered: true
                fontSize: Style.font.body
                horizontalPadding: Style.space(12)
                verticalPadding: Style.space(8)
                foreground: root.foreground
                onClicked: root.saveFavorite()
              }

              CompactSlider {
                label: "Pace"
                value: root.drawSpeed
                minimum: 0
                maximum: 1
                integer: false
                step: 0.01
                valueText: Curve.speedLabel(root.drawSpeed)
                Layout.fillWidth: false
                Layout.preferredWidth: Style.space(140)
                Layout.maximumWidth: Style.space(160)
                Layout.minimumWidth: Style.space(110)
                onMoved: function(v) { root.drawSpeed = v }
              }

              Item {
                Layout.fillWidth: true
                Layout.minimumWidth: Style.space(8)
                Layout.preferredWidth: Style.space(16)
              }

              CompactSlider {
                label: "R"
                value: root.fixedR
                minimum: 40
                maximum: 220
                onMoved: function(v) { root.beginStroke(); root.fixedR = v }
                onReleased: function(v) { root.fixedR = v; root.endStroke() }
              }

              CompactSlider {
                label: "r"
                value: root.rollingR
                minimum: 8
                maximum: 100
                onMoved: function(v) { root.beginStroke(); root.rollingR = v }
                onReleased: function(v) { root.rollingR = v; root.endStroke() }
              }

              CompactSlider {
                label: "p"
                value: root.penP
                minimum: 0
                maximum: root.penCeiling
                onMoved: function(v) { root.beginStroke(); root.penP = v }
                onReleased: function(v) { root.penP = v; root.endStroke() }
              }

              Row {
                spacing: Style.space(6)
                Layout.alignment: Qt.AlignVCenter
                Button {
                  text: "Inside"
                  selected: !root.epi
                  bordered: true
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.space(4)
                  foreground: root.foreground
                  onClicked: { root.beginStroke(); root.epi = false; root.endStroke() }
                }
                Button {
                  text: "Outside"
                  selected: root.epi
                  bordered: true
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.space(4)
                  foreground: root.foreground
                  onClicked: { root.beginStroke(); root.epi = true; root.endStroke() }
                }
              }

              Item {
                Layout.fillWidth: true
                Layout.minimumWidth: Style.space(8)
                Layout.preferredWidth: Style.space(16)
              }

              Button {
                text: "Looks"
                selected: root.openSheet === "looks"
                bordered: true
                fontSize: Style.font.body
                horizontalPadding: Style.space(12)
                verticalPadding: Style.space(8)
                foreground: root.foreground
                onClicked: root.toggleSheet("looks")
              }

              Button {
                text: "Ink"
                selected: root.openSheet === "ink"
                bordered: true
                fontSize: Style.font.body
                horizontalPadding: Style.space(12)
                verticalPadding: Style.space(8)
                foreground: root.foreground
                onClicked: root.toggleSheet("ink")
              }
            }
          }
        }
      }
    }
  }

  component SectionLabel: Text {
    color: root.foreground
    opacity: 0.5
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.2
  }

  component ChipRow: Flow {
    id: chips
    property var model: []
    property string currentKey: ""
    signal picked(string key)
    Layout.fillWidth: true
    spacing: Style.space(6)

    Repeater {
      model: chips.model
      Button {
        required property var modelData
        text: modelData.label
        selected: chips.currentKey === modelData.key
        bordered: true
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(4)
        foreground: root.foreground
        onClicked: chips.picked(modelData.key)
      }
    }
  }

  component CompactSlider: ColumnLayout {
    id: row
    required property string label
    required property real value
    property real minimum: 0
    property real maximum: 100
    property bool integer: true
    property real step: 1
    property string valueText: ""
    signal moved(real value)
    signal released(real value)

    spacing: Style.space(2)
    Layout.fillWidth: true
    Layout.minimumWidth: Style.space(88)
    Layout.preferredWidth: Style.space(128)
    Layout.maximumWidth: Style.space(168)

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: row.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Item { Layout.fillWidth: true }
      Text {
        text: row.valueText !== "" ? row.valueText : String(Math.round(row.value))
        color: root.foreground
        opacity: 0.7
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    PanelSlider {
      Layout.fillWidth: true
      bar: root.fakeBar
      minimum: row.minimum
      maximum: row.maximum
      step: row.step
      integer: row.integer
      value: row.value
      onMoved: function(v) { row.moved(v) }
      onReleased: function(v) { row.released(v) }
    }
  }
}
