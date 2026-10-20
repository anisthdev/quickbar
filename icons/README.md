# Icons

Status icons are Android 16's own, from AOSP (Apache 2.0), branch
`android16-qpr2-release` of `platform/frameworks/base`, converted with
`tools/vd2svg.py`:

| File | AOSP source | Converted with |
|---|---|---|
| wifi_0 … wifi_3 | packages/SettingsLib/res/drawable/ic_wifi_N.xml | |
| wifi_off | packages/SystemUI/res/drawable/ic_signal_wifi_off.xml | |
| ethernet | packages/SystemUI/res/drawable/stat_sys_ethernet_fully.xml | |
| bluetooth | core/res/res/drawable/ic_qs_bluetooth.xml | |
| bluetooth_connected | packages/SystemUI/res/drawable/ic_bluetooth_connected.xml | |
| volume | packages/SystemUI/res/drawable/ic_volume_media.xml | |
| volume_mute | packages/SystemUI/res/drawable/ic_volume_media_mute.xml | |
| volume_bt | packages/SystemUI/res/drawable/ic_volume_media_bt.xml | |
| volume_bt_mute | packages/SystemUI/res/drawable/ic_volume_media_bt_mute.xml | |

`--bold` thickens thin icons that blur on a 1x screen.

Others: `archlinux` is from Simple Icons, `keyboard_command_key` from
Material Symbols Rounded, `close` (notifications) is Material Icons'
close path with the same 0.6 stroke as the converted ones, and `search`,
`download`, `arrow_upward` and `arrow_downward` (the media search) are
Material Symbols. All icons are white; the bar tints them.

Brightness icons (volume and brightness notifications), from
packages/SystemUI/res/drawable; these are Lottie exports, whose bare "c"
path commands vd2svg drops:

| File | AOSP source |
|---|---|
| brightness_low | ic_brightness_low.xml |
| brightness_medium | ic_brightness_medium.xml |
| brightness_full | ic_brightness_full.xml |

Output device icons (audio menu), all from packages/SettingsLib/res/drawable,
converted with `--bold 0.6`:

| File | AOSP source |
|---|---|
| device_laptop | ic_media_computer.xml |
| device_display | ic_external_display.xml |
| device_headphones | ic_headphone.xml |
| device_speaker | ic_media_speaker_device.xml |
| check | ic_check.xml |

Bluetooth device icons (Bluetooth menu), converted with `--bold 0.6`:

| File | AOSP source |
|---|---|
| bt_headphones | core/res/res/drawable/ic_bt_headphones_a2dp.xml |
| bt_headset | core/res/res/drawable/ic_bt_headset_hfp.xml |
| bt_laptop | core/res/res/drawable/ic_bt_laptop.xml |
| bt_input | core/res/res/drawable/ic_bt_misc_hid.xml |
| bt_mouse | core/res/res/drawable/ic_bt_pointing_hid.xml |
| bt_generic | core/res/res/drawable/ic_settings_bluetooth.xml |
| bt_speakers | packages/SettingsLib/res/drawable/ic_bt_le_audio_speakers.xml |
| bt_earbuds | packages/SettingsLib/res/drawable/ic_bt_untethered_earbuds.xml |

Wi-Fi menu:

| File | AOSP source |
|---|---|
| lock | packages/SystemUI/res/drawable/qs_ic_wifi_lock.xml |

Tray overflow, converted with `--bold 0.6`:

| File | AOSP source |
|---|---|
| chevron | core/res/res/drawable/ic_chevron_start.xml |

Weather card detail icons are Material Symbols Rounded (filled), as Pixel
Weather uses for its detail tiles: `wx_air`, `wx_aq`, `wx_compress`,
`wx_humidity_percentage`, `wx_location_on`, `wx_navigation`, `wx_sunny`,
`wx_thermostat`, `wx_water_drop`, `wx_wb_twilight`. The condition icons
themselves are Google's weather icons from waybar-weather
(`~/.config/waybar/weather/.icons/dark`).

Media controls are Material Symbols Rounded (filled): `media_play_arrow`,
`media_pause`, `media_skip_previous`, `media_skip_next`, `media_shuffle`,
`media_repeat`, `media_repeat_one`, `media_music_note`.

Battery card power modes are Material Symbols Rounded (filled):
`power_energy_savings_leaf`, `power_balance`, `power_speed`.

The control panel's sliders, `mic` and `mic_off`, quick note's `edit`
and the clipboard's pin, `keep` (filled), are Material Symbols Rounded. (The power, screenshot and screen
record menus use Papirus icons, as the control panel does.)

The emoji picker's group icons (`schedule` and the `emoji_*` ones) and the
lock screen's `fingerprint` are
Material Symbols Rounded.
