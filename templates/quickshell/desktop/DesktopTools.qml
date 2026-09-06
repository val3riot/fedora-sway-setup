import QtQuick
import Quickshell
import Quickshell.Io
import "../osd"
import "../launcher"
import "../clipboard"
Scope {
    id: root
    required property var audioService
    property string opened: ""
    OsdService { id: osd; audioService: root.audioService }
    Osd { service: osd }
    ClipboardService { id: clipboard; opened: root.opened === "clipboard" }
    Loader {
        active: root.opened === "launcher"
        sourceComponent: AppLauncher { visible: true; onCloseRequested: root.opened = "" }
    }
    Loader {
        active: root.opened === "clipboard"
        sourceComponent: ClipboardPopup { service: clipboard; visible: true; onCloseRequested: root.opened = "" }
    }
    IpcHandler {
        target: "desktop"
        function action(name: string): void {
            if (name === "launcher" || name === "clipboard") root.opened = root.opened === name ? "" : name;
            else if (name === "close") root.opened = "";
            else osd.action(name);
        }
    }
}
