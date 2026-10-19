import Quickshell
import QtQuick
import ".."
import "../components"

// Pixel Weather style card: a hero with the temperature and Google's
// weather icon, and the next 24 hours as a scrolling strip. With
// `showDetails`, the week follows as rows with temperature range bars,
// then detail tiles. Fed by Weather.qml.
Dropdown {
    id: root

    property var data: null
    property string iconDir
    property double updatedAt: 0
    // The week, detail tiles and footer; off for a compact card
    property bool showDetails: false

    readonly property var current: data?.current ?? null
    readonly property var days: data?.daily ?? []
    readonly property string deg: "°"

    // The week's coldest low and warmest high, for scaling the range bars
    readonly property real weekLow: Math.min(...days.map(d => d.low))
    readonly property real weekHigh: Math.max(...days.map(d => d.high))

    readonly property real tileWidth: (menuWidth - 32 - 2 * 6) / 3

    function temp(value) {
        return value === null || value === undefined ? "–" : `${Math.round(value)}${deg}`;
    }
    function icon(name) {
        return `file://${iconDir}/${name}`;
    }
    function localDate(iso) {
        // ISO without an offset is local time, which is what Open-Meteo sends
        return new Date(iso);
    }

    // Temperature colours for the range bars: cool blue, mild yellow, hot
    // orange, as in Pixel Weather
    function tempColor(t) {
        const stops = [[0, "#7cacf8"], [18, "#8fd3c1"], [26, "#fdd663"], [34, "#f29b4b"], [42, "#ee675c"]];
        if (t <= stops[0][0])
            return stops[0][1];
        for (let i = 1; i < stops.length; i++) {
            if (t <= stops[i][0]) {
                const [t0, c0] = stops[i - 1];
                const [t1, c1] = stops[i];
                return Qt.tint(c0, Qt.alpha(c1, (t - t0) / (t1 - t0)));
            }
        }
        return stops[stops.length - 1][1];
    }

    function uvLevel(uv) {
        return uv < 3 ? "Low" : uv < 6 ? "Moderate" : uv < 8 ? "High" : uv < 11 ? "Very high" : "Extreme";
    }
    function aqiLevel(aqi) {
        return aqi <= 50 ? "Good" : aqi <= 100 ? "Moderate" : aqi <= 150 ? "Unhealthy for some" : aqi <= 200 ? "Unhealthy" : aqi <= 300 ? "Very unhealthy" : "Hazardous";
    }
    function compass(degrees) {
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(degrees / 45) % 8];
    }

    menuWidth: 360

    // Loading
    Label {
        anchors.verticalCenter: undefined
        visible: root.current === null
        leftPadding: 12
        topPadding: 12
        bottomPadding: 12
        text: "Fetching the weather…"
        color: Theme.on_surface_variant
    }

    // Hero
    // Now and the next 24 hours, straight on the menu's surface: the hero on
    // top, the hourly strip below a hairline
    Item {
        id: now

        visible: root.current !== null
        width: parent.width
        height: heroArea.height + 1 + hourly.height

        Item {
            id: heroArea

            width: parent.width
            height: 124

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 4

                    Icon {
                        name: "wx_location_on"
                        size: 14
                        color: Theme.on_surface_variant
                    }

                    Label {
                        text: root.data?.location || "Your location"
                        color: Theme.on_surface_variant
                        font.pixelSize: 13
                    }
                }

                Label {
                    anchors.verticalCenter: undefined
                    text: root.temp(root.current?.temperature)
                    color: Theme.on_surface
                    font.pixelSize: 46
                    font.weight: Font.Normal
                }

                Label {
                    anchors.verticalCenter: undefined
                    text: root.current?.label ?? ""
                    color: Theme.on_surface
                    font.pixelSize: 15
                }

                Label {
                    anchors.verticalCenter: undefined
                    text: `Feels like ${root.temp(root.current?.feels_like)} · ↑${root.temp(root.data?.today.high)} ↓${root.temp(root.data?.today.low)}`
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                }
            }

            Image {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                source: root.current ? root.icon(root.current.icon) : ""
                sourceSize: Qt.size(80, 80)
            }

            MenuReveal {
                target: heroArea
                shown: root.open
            }
        }

        Rectangle {
            x: 20
            y: heroArea.height
            width: parent.width - 40
            height: 1
            color: Theme.on_surface
            opacity: 0.1
        }

        ListView {
            id: hourly

            x: 8
            y: heroArea.height + 1
            width: parent.width - 16
            height: 96
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.data?.hourly ?? []

            delegate: Column {
                id: hour

                required property var modelData
                required property int index

                width: 48
                spacing: 4
                topPadding: 4

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: undefined
                    text: hour.index === 0 ? "Now" : Qt.formatDateTime(root.localDate(hour.modelData.time), "h AP")
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                }

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: root.icon(hour.modelData.icon)
                    sourceSize: Qt.size(30, 30)
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: undefined
                    text: root.temp(hour.modelData.temperature)
                    color: Theme.on_surface
                    font.pixelSize: 14
                }

                // Chance of rain, when there's a real one
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1
                    opacity: hour.modelData.precipitation_chance >= 10 ? 1 : 0

                    Icon {
                        name: "wx_water_drop"
                        size: 10
                        color: "#7cacf8"
                    }

                    Label {
                        text: `${Math.round(hour.modelData.precipitation_chance ?? 0)}%`
                        color: "#7cacf8"
                        font.pixelSize: 11
                    }
                }
            }

            MenuReveal {
                target: hourly
                shown: root.open
                index: 1
            }
        }
    }

    // Next 7 days, as a grouped list
    Column {
        id: daily

        visible: root.showDetails && root.current !== null
        width: parent.width
        spacing: 3

        Repeater {
            model: root.days

            Rectangle {
                id: day

                required property var modelData
                required property int index
                readonly property bool first: index === 0
                readonly property bool last: index === root.days.length - 1

                width: parent.width
                height: 44
                topLeftRadius: first ? 20 : 4
                topRightRadius: first ? 20 : 4
                bottomLeftRadius: last ? 20 : 4
                bottomRightRadius: last ? 20 : 4
                color: Theme.surface_container_high

                Label {
                    x: 18
                    width: 58
                    text: day.first ? "Today" : Qt.locale().toString(root.localDate(day.modelData.date + "T12:00"), "ddd")
                    color: Theme.on_surface
                }

                Row {
                    x: 78
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    opacity: day.modelData.precipitation_chance >= 10 ? 1 : 0

                    Icon {
                        name: "wx_water_drop"
                        size: 10
                        color: "#7cacf8"
                    }

                    Label {
                        text: `${Math.round(day.modelData.precipitation_chance ?? 0)}%`
                        color: "#7cacf8"
                        font.pixelSize: 11
                    }
                }

                Image {
                    x: 122
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.icon(day.modelData.icon)
                    sourceSize: Qt.size(28, 28)
                }

                Label {
                    x: 162
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: root.temp(day.modelData.low)
                    color: Theme.on_surface_variant
                }

                // The day's range on the week's scale, coloured by temperature
                Rectangle {
                    id: track

                    x: 206
                    anchors.verticalCenter: parent.verticalCenter
                    width: day.width - x - 58
                    height: 6
                    radius: 3
                    color: Theme.surface_container_highest

                    Rectangle {
                        readonly property real span: Math.max(1, root.weekHigh - root.weekLow)

                        x: (day.modelData.low - root.weekLow) / span * track.width
                        width: Math.max(height, (day.modelData.high - day.modelData.low) / span * track.width)
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: root.tempColor(day.modelData.low)
                            }
                            GradientStop {
                                position: 1
                                color: root.tempColor(day.modelData.high)
                            }
                        }
                    }

                    // Where it is right now, on today's bar
                    Rectangle {
                        visible: day.first && root.current !== null
                        x: ((root.current?.temperature ?? 0) - root.weekLow) / Math.max(1, root.weekHigh - root.weekLow) * track.width - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.on_surface
                        border.width: 2
                        border.color: Theme.surface_container_high
                    }
                }

                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    text: root.temp(day.modelData.high)
                    color: Theme.on_surface
                }

                MenuReveal {
                    target: day
                    shown: root.open
                    index: day.index + 2
                }
            }
        }
    }

    // Details
    Grid {
        id: tiles

        visible: root.showDetails && root.current !== null
        columns: 3
        spacing: 6

        WeatherTile {
            width: root.tileWidth
            icon: "wx_humidity_percentage"
            title: "Humidity"
            value: `${Math.round(root.current?.humidity ?? 0)}%`
            caption: (root.current?.humidity ?? 0) > 70 ? "Humid" : (root.current?.humidity ?? 0) < 30 ? "Dry" : "Comfortable"
        }

        WeatherTile {
            width: root.tileWidth
            icon: "wx_air"
            title: "Wind"
            value: `${Math.round(root.current?.wind_speed ?? 0)}`
            unit: root.data?.units.wind ?? ""
            caption: `From ${root.compass(root.current?.wind_direction ?? 0)}`
            // Points where the wind is going
            accessoryIcon: "wx_navigation"
            accessoryRotation: (root.current?.wind_direction ?? 0) + 180
        }

        WeatherTile {
            width: root.tileWidth
            icon: "wx_sunny"
            title: "UV index"
            value: `${Math.round(root.current?.uv_index ?? 0)}`
            caption: `${root.uvLevel(root.current?.uv_index ?? 0)} · max ${Math.round(root.days[0]?.uv_index_max ?? 0)}`
        }

        WeatherTile {
            width: root.tileWidth
            icon: "wx_aq"
            title: "Air quality"
            value: root.current?.aqi != null ? `${Math.round(root.current.aqi)}` : "–"
            caption: root.current?.aqi != null ? root.aqiLevel(root.current.aqi) : "Unavailable"
        }

        WeatherTile {
            readonly property date sunrise: root.localDate(root.data?.today.sunrise ?? "")
            readonly property date sunset: root.localDate(root.data?.today.sunset ?? "")
            // Whichever comes next today; after sunset, today's sunrise is
            // still the closest thing we know
            readonly property bool sunriseNext: Date.now() < sunrise.getTime() || Date.now() > sunset.getTime()

            width: root.tileWidth
            icon: "wx_wb_twilight"
            title: sunriseNext ? "Sunrise" : "Sunset"
            value: Qt.formatDateTime(sunriseNext ? sunrise : sunset, "h:mm")
            unit: Qt.formatDateTime(sunriseNext ? sunrise : sunset, "AP")
            caption: `${sunriseNext ? "Sunset" : "Sunrise"} ${Qt.formatDateTime(sunriseNext ? sunset : sunrise, "h:mm AP")}`
        }

        WeatherTile {
            width: root.tileWidth
            icon: "wx_compress"
            title: "Pressure"
            value: `${Math.round(root.current?.pressure ?? 0)}`
            unit: "hPa"
            caption: root.current?.visibility_km != null ? `Visibility ${Math.round(root.current.visibility_km)} km` : ""
        }

        MenuReveal {
            target: tiles
            shown: root.open
            index: root.days.length + 2
        }
    }

    Label {
        id: updated

        anchors.verticalCenter: undefined
        visible: root.showDetails && root.current !== null
        width: parent.width
        horizontalAlignment: Text.AlignRight
        rightPadding: 8
        text: `Open-Meteo · updated ${Qt.formatDateTime(new Date(root.updatedAt), "h:mm AP")}`
        color: Theme.on_surface_variant
        font.pixelSize: 11
    }
}
