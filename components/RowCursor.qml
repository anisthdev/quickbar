import QtQuick

// The keyboard's place in a menu's rows: what ListKeys moves when the rows
// come from a Repeater rather than a ListView. -1 until a key moves it, so
// nothing shows highlighted before the keyboard is used.
QtObject {
    property int count: 0
    property int currentIndex: -1

    onCountChanged: if (currentIndex >= count)
        currentIndex = count - 1
}
