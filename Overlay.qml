import QtQuick
import QtQuick.Layouts
import Quickshell
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

  property real fixedR: 100
  property real rollingR: 30
  property real penP: 20

  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family

  readonly property var fakeBar: QtObject {
    readonly property color foreground: root.foreground
    readonly property color background: root.background
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: root.fontFamily
    readonly property string position: "top"
    readonly property bool vertical: false
    readonly property int barSize: 26
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
      root.hostWidget.bar.shell.hide("richardb.quattrograph")
      return
    }
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "richardb.quattrograph")
    else
      close()
  }

  onFixedRChanged: paintTimer.restart()
  onRollingRChanged: paintTimer.restart()
  onPenPChanged: paintTimer.restart()

  Timer {
    id: paintTimer
    interval: 16
    repeat: false
    onTriggered: canvas.requestPaint()
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
        width: Math.min(Style.space(860), keyCatcher.width - Style.space(48))
        height: Math.min(Style.space(560), keyCatcher.height - Style.space(48))
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
            Layout.preferredWidth: Style.space(520)
            Layout.minimumWidth: Style.space(240)
            Layout.minimumHeight: Style.space(240)
            color: Qt.rgba(0, 0, 0, 0.22)
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
                var pts = Curve.pointList(root.fixedR, root.rollingR, root.penP, width, height, 0.02)
                if (pts.length < 2)
                  return
                ctx.strokeStyle = root.accent
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var i = 1; i < pts.length; i++)
                  ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
              }
            }
          }

          ColumnLayout {
            Layout.preferredWidth: Style.space(260)
            Layout.maximumWidth: Style.space(280)
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: Style.space(14)

            Text {
              text: "Quattrograph"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: "Drag sliders to redraw live. Esc or the dimmed edge closes. Super+Shift+I opens it again."
              color: root.foreground
              opacity: 0.7
              wrapMode: Text.Wrap
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

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

            Item { Layout.fillHeight: true }
          }
        }
      }
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
