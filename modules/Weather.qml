import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// Reuses the waybar-weather binary and its Google-style icons; only the
// rendering is new.
Pill {
    id: root

    readonly property string weatherDir: Quickshell.env("HOME") + "/.config/waybar/weather"

    // waybar-weather condition class -> icon file, per time of day
    readonly property var icons: ({
            "clear": ["sunny", "clear_night"],
            "mostly_clear": ["mostly_sunny", "mostly_clear_night"],
            "partly_cloudy": ["partly_cloudy", "partly_cloudy_night"],
            "cloudy": ["cloudy", "cloudy"],
            "fog": ["cloudy", "cloudy"],
            "drizzle": ["drizzle", "drizzle"],
            "light_rain": ["drizzle", "drizzle"],
            "rain": ["heavy_rain", "heavy_rain"],
            "heavy_rain": ["heavy_rain", "heavy_rain"],
            "showers": ["heavy_rain", "heavy_rain"],
            "scattered_showers": ["heavy_rain", "heavy_rain"],
            "sleet_hail": ["sleet_hail", "sleet_hail"],
            "mixed_rain_hail_sleet": ["wintry_mix", "wintry_mix"],
            "light_snow": ["flurries", "flurries"],
            "snow": ["flurries", "flurries"],
            "showers_snow": ["flurries", "flurries"],
            "scattered_snow_showers": ["flurries", "flurries"],
            "heavy_snow": ["heavy_snow", "heavy_snow"],
            "thunderstorms": ["strong_thunderstorms", "strong_thunderstorms"],
            "strong_thunderstorms": ["strong_thunderstorms", "strong_thunderstorms"]
        })

    property string temp: ""
    property string icon: ""

    padding: 10
    visible: temp !== ""

    function parse(raw) {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return;
        }
        temp = data.text ?? "";
        const classes = Array.isArray(data.class) ? data.class : [];
        const night = classes.includes("weather-night");
        const cond = classes.map(c => c.replace(/^weather-/, "")).find(c => icons[c] !== undefined);
        icon = cond ? `${weatherDir}/.icons/dark/${icons[cond][night ? 1 : 0]}.svg` : "";
    }

    Process {
        id: proc
        command: [root.weatherDir + "/waybar-weather"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Image {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        source: root.icon ? "file://" + root.icon : ""
        sourceSize: Qt.size(25, 25)
    }

    Label {
        text: root.temp
    }
}
