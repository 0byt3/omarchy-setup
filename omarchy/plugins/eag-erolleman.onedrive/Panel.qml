import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  moduleName: "eag-erolleman.onedrive"
  ipcTarget: "eag-erolleman.onedrive"
  manageIpc: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function statusColor(status) {
    if (status === "failed") return urgent
    if (status === "offline") return dim
    if (status === "syncing") return Color.accent
    return foreground
  }

  Service {
    id: onedrive
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { onedrive.refresh(); return "ok" }
    function status(): string { return onedrive.serviceText + ": " + onedrive.statusText }
  }

  component OneDriveMark: Item {
    id: mark
    property string status: "offline"

    implicitWidth: Style.space(14)
    implicitHeight: Style.space(14)
    width: implicitWidth
    height: implicitHeight

    Image {
      anchors.centerIn: parent
      source: Qt.resolvedUrl("onedrive.svg")
      sourceSize.width: parent.width
      sourceSize.height: parent.height
      fillMode: Image.PreserveAspectFit
      opacity: mark.status === "offline" ? 0.55 : 1
    }

    Rectangle {
      width: Math.max(5, parent.width * 0.34)
      height: width
      radius: width / 2
      color: root.statusColor(mark.status)
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      border.width: 1
      border.color: Color.background
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: Component {
      Item {
        anchors.fill: parent

        OneDriveMark {
          anchors.centerIn: parent
          status: onedrive.iconStatus
        }
      }
    }
    implicitWidth: Style.space(32)
    tooltipText: "OneDrive · " + onedrive.serviceText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) onedrive.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") onedrive.refresh()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: content
          width: parent.width
          spacing: Style.space(12)

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(14)
            Layout.rightMargin: Style.space(14)
            Layout.topMargin: Style.space(14)
            spacing: Style.space(10)

            OneDriveMark {
              status: onedrive.iconStatus
              Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              Text {
                text: "OneDrive"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                Layout.fillWidth: true
                text: onedrive.serviceText + " · " + onedrive.statusText
                color: root.statusColor(onedrive.iconStatus)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            PanelActionButton {
              iconText: "󰑐"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: onedrive.refresh()
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(14)
            Layout.rightMargin: Style.space(14)
            visible: onedrive.lastError !== ""
            text: onedrive.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(14)
            Layout.rightMargin: Style.space(14)
            height: Style.spacing.hairline
            color: root.foreground
            opacity: 0.12
          }

          Text {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(14)
            Layout.rightMargin: Style.space(14)
            text: onedrive.transfers.length > 0 ? "Synchronizing files" : "No files are currently synchronizing"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: onedrive.transfers

            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Layout.leftMargin: Style.space(14)
              Layout.rightMargin: Style.space(14)
              spacing: Style.space(9)

              Text {
                text: Model.fileGlyph(modelData.path)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.icon
                Layout.alignment: Qt.AlignTop
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(1)

                Text {
                  Layout.fillWidth: true
                  text: modelData.path
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideMiddle
                }

                Text {
                  Layout.fillWidth: true
                  text: Model.transferText(modelData)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(8)
          }
        }
      }
    }
  }
}
