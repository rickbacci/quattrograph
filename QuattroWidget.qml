import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "richardb-quattrograph"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item)
      panelLoader.item.open("{}")
  }

  function close() {
    if (panelLoader.item)
      panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item)
      panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item)
      panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item)
      return
    panelLoader.item.hostWidget = root
    if ("bar" in panelLoader.item)
      panelLoader.item.bar = root.bar
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Overlay.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // The bar widget Component URL is QuattroWidget.qml. Overlay.qml edits
  // would otherwise leave the Loader holding a stale document.
  FileView {
    path: {
      var url = Qt.resolvedUrl("Overlay.qml").toString()
      if (url.indexOf("file://") === 0)
        return decodeURIComponent(url.slice(7))
      return ""
    }
    watchChanges: true
    printErrors: false
    onFileChanged: {
      panelLoader.active = false
      Qt.callLater(function() { panelLoader.active = true })
    }
  }

  IpcHandler {
    target: "richardb-quattrograph"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "QG"
    tooltipText: "Quattrograph"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton)
        root.toggle()
    }
  }
}
