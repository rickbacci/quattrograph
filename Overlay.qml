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
  property bool opened: false
  property bool applyingStore: false
  property bool writingStore: false
  property bool wandering: false
  property bool playSaved: false
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
  property real drawSpeed: Curve.defaultPace()
  property var favorites: []
  property var livePts: []
  property var palette: []
  property real lastPenMs: 0

  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property string fontFamily: Style.font.family
  readonly property real penCeiling: Curve.penMax(root.rollingR)
  readonly property var liveCurve: {
    return {
      fixedR: root.fixedR,
      rollingR: root.rollingR,
      penP: root.penP,
      epi: root.epi
    }
  }
  readonly property var fakeBar: QtObject {
    readonly property color foreground: root.foreground
    readonly property color background: root.background
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: root.fontFamily
    readonly property string position: "top"
    readonly property bool vertical: false
    readonly property int barSize: 26
  }

  Button {
    id: wanderSizer
    visible: false
    text: "Wandering"
    selected: true
    bordered: true
    fontSize: Style.font.body
    horizontalPadding: Style.space(14)
    verticalPadding: Style.space(8)
    foreground: root.foreground
  }

  function currentLook() {
    return Curve.copyLook({
      fixedR: root.fixedR,
      rollingR: root.rollingR,
      penP: root.penP,
      epi: root.epi,
      lineWidth: root.lineWidth,
      inkMode: root.inkMode,
      drawSpeed: root.drawSpeed
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
    if (!preservePace) {
      root.lineWidth = next.lineWidth
      root.inkMode = next.inkMode
      root.drawSpeed = next.drawSpeed
    }
    root.applyingStore = false
    if (sameCurve) {
      if (root.wandering) {
        root.wanderHolding = false
        root.startPen()
      } else if (root.opened) {
        canvas.requestPaint()
      }
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
    root.openSheet = "saved"
  }

  function deleteFavorite(id) {
    var next = []
    for (var i = 0; i < root.favorites.length; i++) {
      if (root.favorites[i].id !== id)
        next.push(root.favorites[i])
    }
    root.favorites = next
    if (!root.favorites.length && root.playSaved)
      root.stopPlay()
    persistNow()
  }

  function rebuildLivePts() {
    if (canvas.width < 8 || canvas.height < 8) {
      root.livePts = []
      return
    }
    root.livePts = Curve.pointList(root.fixedR, root.rollingR, root.penP, canvas.width, canvas.height, 0, root.epi)
  }

  function startPen() {
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

  function stopPlay() {
    var wasPlaying = root.wandering
    root.wanderHolding = false
    root.wandering = false
    root.playSaved = false
    if (wasPlaying)
      persistNow()
  }

  function playSavedLook(look) {
    root.applyLook(look, true)
  }

  function toggleWander() {
    root.openSheet = ""
    if (root.wandering && !root.playSaved) {
      root.stopPlay()
      return
    }
    root.wanderHolding = false
    root.playSaved = false
    root.wandering = true
    root.startPen()
  }

  function toggleFavorites() {
    root.openSheet = ""
    if (root.wandering && root.playSaved) {
      root.stopPlay()
      return
    }
    if (!root.favorites.length)
      return
    root.wanderHolding = false
    root.playSaved = true
    root.wandering = true
    var look = Curve.nextSavedLook(root.currentLook(), root.favorites)
    if (look)
      root.playSavedLook(look)
    else
      root.startPen()
  }

  function advanceWander() {
    if (!root.wandering || !root.opened)
      return
    if (root.playSaved) {
      var saved = Curve.nextSavedLook(root.currentLook(), root.favorites)
      if (!saved) {
        root.stopPlay()
        return
      }
      root.playSavedLook(saved)
      return
    }
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
    root.playSaved = false
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

  function dismiss() {
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
  onDrawSpeedChanged: persistTimer.restart()

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
        if (now >= root.holdUntil)
          root.advanceWander()
        return
      }
      var before = root.penT
      root.penT += dt * rate
      if (before < 1 && root.penT >= 1) {
        root.penT = 1
        canvas.requestPaint()
        if (root.wandering) {
          root.wanderHolding = true
          root.holdUntil = now + 1800
        } else {
          penTimer.stop()
        }
        return
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
      color: root.scrim
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
          color: root.background
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
              ctx.fillStyle = root.colorCss(root.foreground).toString()
              ctx.beginPath()
              ctx.arc(tip.x, tip.y, Math.max(3, root.lineWidth + 1.5), 0, Math.PI * 2)
              ctx.fill()
            }
          }
        }

        Rectangle {
          id: savedSheet
          visible: root.openSheet === "saved"
          z: 40
          anchors.right: parent.right
          anchors.bottom: toolRest.top
          anchors.margins: Style.space(12)
          width: savedCol.implicitWidth + Style.space(28)
          height: savedCol.implicitHeight + Style.space(28)
          color: root.background
          radius: Style.cornerRadius
          border.color: root.border
          border.width: Math.max(1, Style.space(1))

          MouseArea {
            anchors.fill: parent
            onClicked: {}
          }

          ColumnLayout {
            id: savedCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(14)
            spacing: Style.space(10)

            SectionLabel { text: "Saved" }

            Text {
              visible: root.favorites.length === 0
              text: "Nothing saved yet."
              color: root.foreground
              opacity: 0.55
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            GridLayout {
              columns: 3
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)
              visible: root.favorites.length > 0
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
          width: inkChips.implicitWidth + Style.space(28)
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
            anchors.top: parent.top
            anchors.margins: Style.space(14)
            width: inkChips.implicitWidth
            spacing: Style.space(10)

            SectionLabel { text: "Ink" }

            CompactSlider {
              label: "Width"
              value: root.lineWidth
              minimum: 1
              maximum: 8
              Layout.minimumWidth: inkChips.implicitWidth
              Layout.preferredWidth: inkChips.implicitWidth
              Layout.maximumWidth: inkChips.implicitWidth
              onMoved: function(v) { root.lineWidth = v }
            }

            Row {
              id: inkChips
              spacing: Style.space(6)
              Button {
                text: "Theme"
                selected: root.inkMode === "theme"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                foreground: root.foreground
                onClicked: root.inkMode = "theme"
              }
              Button {
                text: "Rainbow"
                selected: root.inkMode === "path"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                foreground: root.foreground
                onClicked: root.inkMode = "path"
              }
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
          color: Color.menu.selectedBackground

          RowLayout {
            id: barInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            spacing: Style.space(12)

            RowLayout {
              id: restRow
              Layout.fillWidth: true
              spacing: Style.space(10)
              opacity: root.wandering ? 0.58 : 1
              Behavior on opacity { NumberAnimation { duration: 220 } }

              Row {
                spacing: Style.space(6)
                Layout.alignment: Qt.AlignVCenter
                Button {
                  text: "Inside"
                  selected: !root.epi
                  bordered: true
                  fontSize: Style.font.body
                  horizontalPadding: Style.space(12)
                  verticalPadding: Style.space(8)
                  foreground: root.foreground
                  onClicked: { root.beginStroke(); root.epi = false; root.endStroke() }
                }
                Button {
                  text: "Outside"
                  selected: root.epi
                  bordered: true
                  fontSize: Style.font.body
                  horizontalPadding: Style.space(12)
                  verticalPadding: Style.space(8)
                  foreground: root.foreground
                  onClicked: { root.beginStroke(); root.epi = true; root.endStroke() }
                }
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
                Layout.minimumWidth: Style.space(88)
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

              Item {
                Layout.fillWidth: true
                Layout.minimumWidth: Style.space(8)
                Layout.preferredWidth: Style.space(16)
              }

              Button {
                text: "Saved"
                selected: root.openSheet === "saved"
                bordered: true
                fontSize: Style.font.body
                horizontalPadding: Style.space(12)
                verticalPadding: Style.space(8)
                foreground: root.foreground
                onClicked: root.toggleSheet("saved")
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

            Item {
              Layout.preferredWidth: Style.space(12)
              Layout.minimumWidth: Style.space(12)
              Layout.maximumWidth: Style.space(12)
              Layout.fillWidth: false
            }

            Button {
              text: root.wandering && !root.playSaved ? "Wandering" : "Wander"
              selected: root.wandering && !root.playSaved
              bordered: true
              fontSize: Style.font.body
              horizontalPadding: Style.space(14)
              verticalPadding: Style.space(8)
              foreground: root.foreground
              Layout.minimumWidth: wanderSizer.implicitWidth
              Layout.preferredWidth: wanderSizer.implicitWidth
              Layout.maximumWidth: wanderSizer.implicitWidth
              onClicked: root.toggleWander()
            }

            Button {
              visible: root.favorites.length > 0
              text: "Favorites"
              selected: root.wandering && root.playSaved
              bordered: true
              fontSize: Style.font.body
              horizontalPadding: Style.space(12)
              verticalPadding: Style.space(8)
              foreground: root.foreground
              onClicked: root.toggleFavorites()
            }

            Item {
              Layout.preferredWidth: Style.space(12)
              Layout.minimumWidth: Style.space(12)
              Layout.maximumWidth: Style.space(12)
              Layout.fillWidth: false
            }

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
    Layout.minimumWidth: Style.space(64)
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
