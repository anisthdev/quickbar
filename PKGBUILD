# Maintainer: Asif Arbaj <asifarbaj@gmail.com>
_name=quickbar
pkgname=totoro-quickbar
pkgver=r93.0702565
pkgrel=1
pkgdesc="Keyboard-first Quickshell desktop shell for Hyprland (run with qs -c quickbar)"
arch=('any')
url="https://github.com/anisthdev/quickbar"
provides=('quickbar')
conflicts=('quickbar')
replaces=('quickbar')
license=('unknown')
depends=(
    'quickshell'
    'hyprland'
    'python'
    'python-gobject'   # the file chooser portal
    'wl-clipboard'
    'libnotify'
    'glib2'            # gio trash
    'xdg-utils'
)
optdepends=(
    'mpd: music player and library'
    'mpc: music player and library'
    'matugen: wallpaper picker colours'
    'awww: wallpaper'
    'grim: screenshots'
    'slurp: region screenshots'
    'hyprshot: screenshots'
    'wl-screenrec: screen recording'
    'totoro-systray: the recording tray icon (tray run)'
    'satty: screenshot editing'
    'imv: screenshot preview'
    'hyprpicker: colour picker'
    'tesseract: text from a region (OCR)'
    'ffmpeg: video library'
    'ffmpegthumbnailer: video library thumbnails'
    'imagemagick: thumbnails'
    'ydotool: on-screen keyboard'
    'networkmanager: Wi-Fi in the control panel'
    'pipewire-audio: sounds (pw-play)'
    'fprintd: fingerprint unlock'
    'python-icalendar: agenda'
    'python-recurring-ical-events: agenda'
    'python-fonttools: glyph picker'
    'transmission-cli: torrents in media search'
    'jq: media search'
    'yq: media search'
    'curl: media search'
    'retroarch: games menu'
    'uwsm: launching apps'
    'xdg-desktop-portal-hyprland: screen sharing (and its picker while quickbar is not running)'
)
makedepends=('git')
source=("git+$url.git")
sha256sums=('SKIP')

pkgver() {
    cd "$_name"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

package() {
    cd "$_name"
    make DESTDIR="$pkgdir" PREFIX=/usr install
}
