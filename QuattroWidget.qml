import QtQuick
import qs.Ui
import "Quattrograph.js" as Curve

BarWidget {
  id: root
  moduleName: "richardb-quattrograph"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Quattrograph"
    iconComponent: Component {
      Canvas {
        id: mark
        anchors.fill: parent
        antialiasing: true

        property color ink: button.foreground
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          if (width < 2 || height < 2)
            return
          var stroke = Math.max(1.35, Math.min(width, height) * 0.1)
          var extent = 4
          var scale = (Math.min(width, height) / 2 - stroke) / extent
          var cx = width / 2
          var cy = height / 2
          var steps = 64
          ctx.strokeStyle = mark.ink.toString()
          ctx.lineWidth = stroke
          ctx.lineJoin = "round"
          ctx.lineCap = "round"
          ctx.beginPath()
          for (var i = 0; i <= steps; i++) {
            var pt = Curve.curvePoint(4, 1, 1, (Math.PI * 2 * i) / steps, false)
            var x = cx + pt.x * scale
            var y = cy + pt.y * scale
            if (i === 0)
              ctx.moveTo(x, y)
            else
              ctx.lineTo(x, y)
          }
          ctx.closePath()
          ctx.stroke()
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode !== Qt.LeftButton || !root.bar || !root.bar.shell)
        return
      root.bar.shell.toggle("richardb-quattrograph", "{}")
    }
  }
}
