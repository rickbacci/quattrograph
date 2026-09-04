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

  property real fixedR: 100
  property real rollingR: 30
  property real penP: 20
  property bool epi: false
  property real lineWidth: 2
  property string inkMode: "solid"
  property string strokeKey: "accent"
  property string paper: "inset"
  property var favorites: []

  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family
  readonly property var presetList: Curve.presets()
  readonly property color paperColor: root.paper === "lift"
    ? Color.menu.selectedBackground
    : Qt.rgba(0, 0, 0, 0.28)
  readonly property color inkColor: {
    if (root.strokeKey === "foreground") return Color.foreground
    if (root.strokeKey === "muted") return Color.muted
    if (root.strokeKey === "urgent") return Color.urgent
    return Color.accent
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

  function currentLook() {
    return Curve.copyLook({
      fixedR: root.fixedR,
      rollingR: root.rollingR,
      penP: root.penP,
      epi: root.epi,
      lineWidth: root.lineWidth,
      inkMode: root.inkMode,
      strokeKey: root.strokeKey,
      paper: root.paper
    })
  }

  function applyLook(look) {
    var next = Curve.copyLook(look)
    root.applyingStore = true
    root.fixedR = next.fixedR
    root.rollingR = next.rollingR
    root.penP = next.penP
    root.epi = next.epi
    root.lineWidth = next.lineWidth
    root.inkMode = next.inkMode
    root.strokeKey = next.strokeKey
    root.paper = next.paper
    root.applyingStore = false
    paintTimer.restart()
    persistTimer.restart()
  }

  function persistNow() {
    if (root.applyingStore)
      return
    storeFile.setText(Curve.serializeStore({
      last: root.currentLook(),
      favorites: root.favorites
    }))
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

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() {
      if (!root.opened)
        return
      keyCatcher.forceActiveFocus()
      paintTimer.restart()
    })
  }

  function close() {
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
    return "hsl(" + hue + ", 72%, 62%)"
  }

  onFixedRChanged: { paintTimer.restart(); persistTimer.restart() }
  onRollingRChanged: { paintTimer.restart(); persistTimer.restart() }
  onPenPChanged: { paintTimer.restart(); persistTimer.restart() }
  onEpiChanged: { paintTimer.restart(); persistTimer.restart() }
  onLineWidthChanged: { paintTimer.restart(); persistTimer.restart() }
  onInkModeChanged: { paintTimer.restart(); persistTimer.restart() }
  onStrokeKeyChanged: { paintTimer.restart(); persistTimer.restart() }
  onPaperChanged: { paintTimer.restart(); persistTimer.restart() }
  onInkColorChanged: paintTimer.restart()

  Timer {
    id: paintTimer
    interval: 16
    repeat: false
    onTriggered: canvas.requestPaint()
  }

  Timer {
    id: persistTimer
    interval: 350
    repeat: false
    onTriggered: root.persistNow()
  }

  FileView {
    id: storeFile
    path: Quickshell.env("HOME") + "/.config/omarchy/quattrograph.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var store = Curve.parseStore(text())
      root.favorites = store.favorites
      if (store.last)
        root.applyLook(store.last)
    }
    onLoadFailed: {
      root.favorites = []
    }
    onFileChanged: reload()
  }

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
      Keys.onEscapePressed: root.dismiss()

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(920), keyCatcher.width - Style.space(48))
        height: Math.min(Style.space(620), keyCatcher.height - Style.space(48))
        color: root.background
        radius: Style.cornerRadius
        border.color: root.border
        border.width: Math.max(1, Style.space(1))

        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(20)
          spacing: Style.space(20)

          Rectangle {
            id: drawBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Style.space(540)
            Layout.minimumWidth: Style.space(240)
            Layout.minimumHeight: Style.space(240)
            color: root.paperColor
            radius: Style.cornerRadius
            clip: true

            Canvas {
              id: canvas
              anchors.fill: parent
              antialiasing: true
              renderStrategy: Canvas.Immediate

              onWidthChanged: paintTimer.restart()
              onHeightChanged: paintTimer.restart()

              onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                var pts = Curve.pointList(root.fixedR, root.rollingR, root.penP, width, height, 0.02, root.epi)
                if (pts.length < 2)
                  return
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.lineWidth = root.lineWidth
                if (root.inkMode !== "path") {
                  ctx.strokeStyle = root.inkColor
                  ctx.beginPath()
                  ctx.moveTo(pts[0].x, pts[0].y)
                  for (var i = 1; i < pts.length; i++)
                    ctx.lineTo(pts[i].x, pts[i].y)
                  ctx.stroke()
                  return
                }
                var stride = Math.max(1, Math.floor(pts.length / 160))
                for (var s = 0; s < pts.length - 1; s += stride) {
                  var end = Math.min(pts.length - 1, s + stride)
                  ctx.beginPath()
                  ctx.strokeStyle = root.hslStroke(s / pts.length)
                  ctx.moveTo(pts[s].x, pts[s].y)
                  for (var j = s + 1; j <= end; j++)
                    ctx.lineTo(pts[j].x, pts[j].y)
                  ctx.stroke()
                }
              }
            }
          }

          Flickable {
            id: controls
            Layout.preferredWidth: Style.space(280)
            Layout.maximumWidth: Style.space(300)
            Layout.fillWidth: false
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: controlColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: controlColumn
              width: controls.width
              spacing: Style.space(12)

              Text {
                text: "Quattrograph"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Esc or the dimmed edge closes."
                color: root.foreground
                opacity: 0.65
                wrapMode: Text.Wrap
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.fillWidth: true
              }

              SectionLabel { text: "Curve" }

              SliderRow {
                label: "R"
                help: "Fixed circle"
                value: root.fixedR
                minimum: 50
                maximum: 200
                onMoved: function(v) { root.fixedR = v }
              }

              SliderRow {
                label: "r"
                help: "Rolling circle"
                value: root.rollingR
                minimum: 10
                maximum: 100
                onMoved: function(v) { root.rollingR = v }
              }

              SliderRow {
                label: "p"
                help: "Pen distance"
                value: root.penP
                minimum: 0
                maximum: 80
                onMoved: function(v) { root.penP = v }
              }

              SliderRow {
                label: "Width"
                help: "Stroke"
                value: root.lineWidth
                minimum: 1
                maximum: 6
                onMoved: function(v) { root.lineWidth = v }
              }

              ChipRow {
                model: [
                  { key: "hypo", label: "Hypo" },
                  { key: "epi", label: "Epi" }
                ]
                currentKey: root.epi ? "epi" : "hypo"
                onPicked: function(key) { root.epi = key === "epi" }
              }

              SectionLabel { text: "Ink" }

              ChipRow {
                model: [
                  { key: "solid", label: "Solid" },
                  { key: "path", label: "Along path" }
                ]
                currentKey: root.inkMode
                onPicked: function(key) { root.inkMode = key }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)
                Repeater {
                  model: [
                    { key: "accent", color: Color.accent },
                    { key: "foreground", color: Color.foreground },
                    { key: "muted", color: Color.muted },
                    { key: "urgent", color: Color.urgent }
                  ]
                  Rectangle {
                    required property var modelData
                    width: Style.space(22)
                    height: Style.space(22)
                    radius: width / 2
                    color: modelData.color
                    border.color: root.strokeKey === modelData.key ? root.foreground : root.border
                    border.width: root.strokeKey === modelData.key ? 2 : 1
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.strokeKey = modelData.key
                    }
                  }
                }
                Item { Layout.fillWidth: true }
              }

              ChipRow {
                model: [
                  { key: "inset", label: "Inset paper" },
                  { key: "lift", label: "Lift paper" }
                ]
                currentKey: root.paper
                onPicked: function(key) { root.paper = key }
              }

              SectionLabel { text: "Looks" }

              Repeater {
                model: root.presetList
                LookRow {
                  required property var modelData
                  title: modelData.name
                  onApply: root.applyLook(modelData.look)
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "Favorites"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  Layout.fillWidth: true
                }
                Button {
                  text: root.favorites.length >= 12 ? "Full" : "Save"
                  enabled: root.favorites.length < 12
                  bordered: true
                  fontSize: Style.font.caption
                  onClicked: root.saveFavorite()
                }
              }

              Text {
                visible: root.favorites.length === 0
                text: "Save a look when the curve is right."
                color: root.foreground
                opacity: 0.55
                wrapMode: Text.Wrap
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.fillWidth: true
              }

              Repeater {
                model: root.favorites
                LookRow {
                  required property var modelData
                  title: modelData.name
                  removable: true
                  onApply: root.applyLook(modelData.look)
                  onRemove: root.deleteFavorite(modelData.id)
                }
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

  component LookRow: RowLayout {
    id: look
    property string title: ""
    property bool removable: false
    signal apply()
    signal remove()
    Layout.fillWidth: true
    spacing: Style.space(6)

    Button {
      text: look.title
      Layout.fillWidth: true
      bordered: true
      fontSize: Style.font.caption
      leftAlign: true
      foreground: root.foreground
      onClicked: look.apply()
    }
    Button {
      visible: look.removable
      text: "×"
      bordered: true
      fontSize: Style.font.caption
      horizontalPadding: Style.space(8)
      onClicked: look.remove()
    }
  }

  component SliderRow: ColumnLayout {
    id: row
    required property string label
    required property string help
    required property real value
    property real minimum: 0
    property real maximum: 100
    signal moved(real value)

    Layout.fillWidth: true
    spacing: Style.space(4)

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: row.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        text: row.help
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.fillWidth: true
      }
      Text {
        text: String(Math.round(row.value))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    PanelSlider {
      Layout.fillWidth: true
      bar: root.fakeBar
      minimum: row.minimum
      maximum: row.maximum
      step: 1
      integer: true
      value: row.value
      onMoved: function(v) { row.moved(v) }
    }
  }
}
