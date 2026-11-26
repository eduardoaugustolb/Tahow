pragma Singleton
import QtQuick
import Quickshell

// Shared wall clock for core consumers that need the time without the Hub.
Singleton {
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
}