import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#2b2b2b"

    property var listNodes: null
    property var summary: []
    property var byRank: []
    property var timeline: []
    property int eventCount: 0
    property real maxTime: 0
    property int timelineBuckets: 100
    property bool hideSelf: true
    property double programDuration: 0
    property double totalMpiTime: 0
    property int sortColumn: 0
    property bool sortAscending: true

    function fmtDuration(sec) {
        if (sec >= 1) return sec.toFixed(3) + " s"
        if (sec >= 0.001) return (sec * 1000).toFixed(2) + " ms"
        return (sec * 1000000).toFixed(1) + " µs"
    }

    function percent(sec) {
        var den = totalMpiTime > 0 ? totalMpiTime : programDuration
        if (den <= 0) return ""
        return (sec / den * 100).toFixed(1) + "%"
    }

    function reload() {
        if (listNodes && listNodes.slurm_id > 0) {
            controller.loadRunHistory(listNodes.slurm_id, hideSelf)
            eventCount = controller.runHistoryModel ? controller.runHistoryModel.count() : 0
            programDuration = controller.getProgramDuration(listNodes.slurm_id)
            totalMpiTime = controller.getTotalMpiTime(listNodes.slurm_id, hideSelf)
            summary = controller.getWaitTimeSummary(listNodes.slurm_id, hideSelf)
            byRank = controller.getWaitTimeByRank(listNodes.slurm_id, hideSelf)
            timeline = controller.getWaitTimeTimeline(listNodes.slurm_id, hideSelf, timelineBuckets)
            var m = 0
            for (var i = 0; i < timeline.length; i++) {
                if (timeline[i].time > m) m = timeline[i].time
            }
            maxTime = m
        }
    }

    onListNodesChanged: reload()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Text {
            text: "Operation history  (" + eventCount + " events)  —  program time " + root.fmtDuration(programDuration) + "  ·  MPI time " + root.fmtDuration(totalMpiTime)
            color: "#00FF00"
            font.pointSize: 12
        }

        CheckBox {
            id: hideSelfCheck
            text: "Hide self-directed operations (partner = own rank)"
            checked: hideSelf
            onCheckedChanged: {
                hideSelf = checked
                reload()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Total time in MPI calls, by function  (% of MPI time)"
                    visible: summary.length > 0
                    color: "#ffcc00"
                    font.pointSize: 10
                    font.bold: true
                }

                ListView {
                    id: functionList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(summary.length, 6) * 21
                    visible: summary.length > 0
                    clip: true
                    model: summary
                    delegate: RowLayout {
                        width: functionList.width
                        height: 20
                        spacing: 4
                        Text { text: modelData.function; color: "white"; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11 }
                        Text { text: "×" + modelData.count; color: "#aaaaaa"; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                        Text { text: root.fmtDuration(modelData.time); color: "#ffcc00"; Layout.preferredWidth: 72; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                        Text { text: root.percent(modelData.time); color: "#88cc88"; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Total time by rank"
                    visible: byRank.length > 0
                    color: "#ffcc00"
                    font.pointSize: 10
                    font.bold: true
                }

                ListView {
                    id: rankList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(byRank.length, 6) * 21
                    visible: byRank.length > 0
                    clip: true
                    model: byRank
                    delegate: RowLayout {
                        width: rankList.width
                        height: 20
                        spacing: 4
                        Text { text: "Rank " + modelData.rank; color: "white"; Layout.preferredWidth: 64; font.pixelSize: 11 }
                        Text { text: "×" + modelData.count; color: "#aaaaaa"; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                        Text { text: root.fmtDuration(modelData.time); color: "#ffcc00"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                    }
                }
            }
        }

        Text {
            text: "Wait time over run"
            visible: timeline.length > 0
            color: "#ffcc00"
            font.pointSize: 10
            font.bold: true
        }

        Item {
            id: timelinePlot
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            visible: timeline.length > 0

            Repeater {
                model: timeline
                delegate: Rectangle {
                    x: (modelData.bucket - 1) * (timelinePlot.width / root.timelineBuckets)
                    width: Math.max(1, timelinePlot.width / root.timelineBuckets - 1)
                    height: root.maxTime > 0 ? Math.max(1, (modelData.time / root.maxTime) * timelinePlot.height) : 0
                    y: timelinePlot.height - height
                    color: "#ffaa00"
                }
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                text: "peak " + root.fmtDuration(root.maxTime) + " / bucket"
                color: "#aaaaaa"
                font.pixelSize: 10
            }
        }

        Row {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { label: "Time", width: 90, col: 0 },
                    { label: "Rank", width: 44, col: 1 },
                    { label: "Function", width: 170, col: 2 },
                    { label: "Partner", width: 55, col: 3 },
                    { label: "Send", width: 70, col: 4 },
                    { label: "Recv", width: 70, col: 5 },
                    { label: "Type", width: 90, col: 6 },
                    { label: "Duration", width: 85, col: 7 },
                    { label: "Disp", width: 55, col: 8 },
                    { label: "WinBase", width: 130, col: 9 },
                    { label: "WinIdx", width: 50, col: 10 },
                    { label: "Call sites", width: 330, col: 11 }
                ]

                delegate: Text {
                    width: modelData.width
                    color: root.sortColumn === modelData.col ? "#00FF00" : "#00cc55"
                    font.bold: true
                    text: modelData.label + (root.sortColumn === modelData.col ? (root.sortAscending ? " ▲" : " ▼") : "")

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sortColumn === modelData.col) {
                                root.sortAscending = !root.sortAscending
                            } else {
                                root.sortColumn = modelData.col
                                root.sortAscending = true
                            }
                            controller.sortRunHistory(root.sortColumn, root.sortAscending)
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: controller.runHistoryModel
            ScrollBar.vertical: ScrollBar { }

            delegate: Rectangle {
                width: list.width
                height: 22
                color: index % 2 === 0 ? "#3a3a3a" : "#2f2f2f"

                Row {
                    anchors.fill: parent
                    spacing: 4
                    Text { text: model.time; width: 90; color: "#cccccc"; elide: Text.ElideRight }
                    Text { text: model.rank; width: 44; color: "white" }
                    Text { text: model.func; width: 170; color: "white"; elide: Text.ElideRight }
                    Text { text: model.partner; width: 55; color: "white" }
                    Text { text: model.send; width: 70; color: "#88cc88"; horizontalAlignment: Text.AlignRight }
                    Text { text: model.recv; width: 70; color: "#cc8888"; horizontalAlignment: Text.AlignRight }
                    Text { text: model.type; width: 90; color: "#88aacc"; elide: Text.ElideRight }
                    Text { text: model.duration; width: 85; color: "#ffcc00"; horizontalAlignment: Text.AlignRight }
                    Text { text: model.displacement; width: 55; color: "#ccaa88"; horizontalAlignment: Text.AlignRight }
                    Text { text: model.window; width: 130; color: "#aaddcc" }
                    Text { text: model.winindex; width: 50; color: "#ddccaa" }
                    Text { text: model.callsites; width: 330; color: "#bbaacc"; elide: Text.ElideRight }
                }
            }
        }
    }
}
