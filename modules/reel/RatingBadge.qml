import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"

// One score on a title's page, inline as Trakt shows them: the source's
// logo in its own colours (from icons/ratings, Simple Icons' marks) and the
// score beside it. IMDb's is its yellow plate, a PNG; Rotten Tomatoes'
// tomato and Metacritic's disc take the colour of the score, as on their
// sites; MyAnimeList's wordmark sits on its blue.
Row {
    id: root

    // imdb, rt, metacritic, tmdb or mal
    property string source
    property real score

    readonly property var look: ({
            imdb: {
                tint: "#f5c518",
                plate: "#f5c518",
                size: 18
            },
            rt: {
                tint: score >= 60 ? "#fa320a" : "#0ac855",
                size: 20
            },
            metacritic: {
                tint: score >= 61 ? "#00ce7a" : score >= 40 ? "#ffbd3f" : "#ff6874",
                size: 20
            },
            tmdb: {
                tint: "#01b4e4",
                size: 18
            },
            mal: {
                tint: "#ffffff",
                plate: "#2e51a2",
                size: 7
            }
        })[source] ?? null

    spacing: 7
    visible: look !== null

    // The logo, rounded off, on its plate where it has one
    ClippingRectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.source === "imdb" ? Math.round(height * 140 / 72) : root.look?.plate ? logo.implicitWidth + 8 : logo.implicitWidth
        height: root.source === "imdb" ? (root.look?.size ?? 18) : root.look?.plate ? 18 : logo.implicitHeight
        radius: root.source === "imdb" ? 3 : 4
        color: root.look?.plate ?? "transparent"

        Icon {
            id: logo

            anchors.centerIn: parent
            visible: root.source !== "imdb"
            name: visible ? `ratings/${root.source}` : ""
            size: root.look?.size ?? 18
            color: root.look?.tint ?? Theme.on_surface
        }

        // IMDb's plate, drawn ahead of time: Qt's SVG renderer loses it
        Image {
            visible: root.source === "imdb"
            anchors.centerIn: parent
            source: visible ? Qt.resolvedUrl("../../icons/ratings/imdb.png") : ""
            sourceSize.height: height * 2
            height: root.look?.size ?? 18
            width: height * 140 / 72
            smooth: true
        }
    }

    Label {
        text: root.source === "rt" ? `${Math.round(root.score)}%` : root.source === "metacritic" ? `${Math.round(root.score)}` : root.score.toFixed(1)
        color: Theme.on_surface
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }
}
