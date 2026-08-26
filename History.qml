import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#2b2b2b"

    property var listNodes: null
    property var rows: []
    property var summary: []
    property var byRank: []
    property var timeline: []
    property real maxTime: 0
    property int limit: 20000
    property int timelineBuckets: 100
    property bool hideSelf: true

    function fmtDuration(sec) {
        if (sec >= 1) return sec.toFixed(3) + " s"
        if (sec >= 0.001) return (sec * 1000).toFixed(2) + " ms"
        return (sec * 1000000).toFixed(1) + " µs"
    }

    function reload() {
        if (listNodes && listNodes.slurm_id > 0) {
            rows = controller.getRunHistory(listNodes.slurm_id, limit, hideSelf)
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
            text: "Operation history  (" + rows.length + " events, in recording order" + (rows.length >= limit ? " — capped at " + limit : "") + ")"
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
                    text: "Total time in MPI calls, by function"
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
                        Text { text: "×" + modelData.count; color: "#aaaaaa"; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                        Text { text: root.fmtDuration(modelData.time); color: "#ffcc00"; Layout.preferredWidth: 78; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { text: "Time"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 90 }
            Text { text: "Rank"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 44 }
            Text { text: "Function"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 200 }
            Text { text: "Partner"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 60 }
            Text { text: "Send"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 84 }
            Text { text: "Recv"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 84 }
            Text { text: "Type"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 100 }
            Text { text: "Duration"; color: "#00FF00"; font.bold: true; Layout.preferredWidth: 90 }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: rows
            ScrollBar.vertical: ScrollBar { }

            delegate: Rectangle {
                width: list.width
                height: 22
                color: index % 2 === 0 ? "#3a3a3a" : "#2f2f2f"

                RowLayout {
                    anchors.fill: parent
                    spacing: 4
                    Text { text: modelData.time; color: "#cccccc"; Layout.preferredWidth: 90; elide: Text.ElideRight }
                    Text { text: modelData.rank; color: "white"; Layout.preferredWidth: 44 }
                    Text { text: modelData.function; color: "white"; Layout.preferredWidth: 200; elide: Text.ElideRight }
                    Text { text: modelData.partner; color: "white"; Layout.preferredWidth: 60 }
                    Text { text: modelData.send; color: "#88cc88"; Layout.preferredWidth: 84; horizontalAlignment: Text.AlignRight }
                    Text { text: modelData.recv; color: "#cc8888"; Layout.preferredWidth: 84; horizontalAlignment: Text.AlignRight }
                    Text { text: modelData.type; color: "#88aacc"; Layout.preferredWidth: 100; elide: Text.ElideRight }
                    Text { text: root.fmtDuration(modelData.duration); color: "#ffcc00"; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }
}
