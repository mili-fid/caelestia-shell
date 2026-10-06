pragma Singleton

import QtQuick
import Quickshell

// State for the dashboard timer card. A singleton because the dashboard's content is destroyed when it closes,
// and the timer has to keep running. Times come from the clock, so it stays correct however long it runs.
Singleton {
    id: root

    property bool stopwatch

    // Countdown
    property real duration: 25 * 60000
    property real remainingAtPause: duration
    property real endTime
    property bool timerRunning
    property bool finished

    // Stopwatch
    property real startTime
    property real elapsedAtPause
    property bool swRunning
    property list<real> laps: []

    property real now: Date.now()

    // For the top-border pill: the dial's digits it flies to and from, and how far it has taken their place (0-1)
    property Item dialDigits
    property real dialHandoff

    readonly property real remaining: timerRunning ? Math.max(0, endTime - now) : remainingAtPause
    readonly property real elapsed: swRunning ? now - startTime : elapsedAtPause
    readonly property bool running: stopwatch ? swRunning : timerRunning
    readonly property real lastLapAt: laps.reduce((sum, lap) => sum + lap, 0)

    function toggle(): void {
        if (running)
            pause();
        else
            start();
    }

    function start(): void {
        now = Date.now();
        if (stopwatch) {
            startTime = now - elapsedAtPause;
            swRunning = true;
        } else {
            if (remainingAtPause <= 0)
                remainingAtPause = duration;
            finished = false;
            endTime = now + remainingAtPause;
            finishTimer.interval = remainingAtPause;
            finishTimer.restart();
            timerRunning = true;
        }
        ticker.restart();
    }

    function pause(): void {
        now = Date.now();
        if (stopwatch) {
            elapsedAtPause = now - startTime;
            swRunning = false;
        } else {
            remainingAtPause = Math.max(0, endTime - now);
            finishTimer.stop();
            timerRunning = false;
        }
    }

    function reset(): void {
        if (stopwatch) {
            swRunning = false;
            elapsedAtPause = 0;
            laps = [];
        } else {
            finishTimer.stop();
            timerRunning = false;
            finished = false;
            remainingAtPause = duration;
        }
        now = Date.now();
    }

    function setDuration(ms: real): void {
        if (timerRunning)
            return;
        duration = Math.max(1000, Math.min(ms, 100 * 3600000 - 1000));
        remainingAtPause = duration;
        finished = false;
    }

    // Scrolling on the minutes or seconds while the timer isn't running
    function adjust(deltaMs: real): void {
        if (timerRunning)
            return;
        setDuration(Math.round((remainingAtPause > 0 ? remainingAtPause : duration) / 1000) * 1000 + deltaMs);
    }

    function addMinute(): void {
        if (!timerRunning) {
            adjust(60000);
            return;
        }
        duration += 60000;
        endTime += 60000;
        now = Date.now();
        finishTimer.interval = endTime - now;
        finishTimer.restart();
    }

    function lap(): void {
        if (!swRunning)
            return;
        now = Date.now();
        laps = [...laps, now - startTime - lastLapAt];
    }

    function acknowledge(): void {
        finished = false;
    }

    function format(ms: real, roundUp: bool): string {
        const total = Math.max(0, roundUp ? Math.ceil(ms / 1000) : Math.floor(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
    }

    // Only ticks while something is running, and only once a second
    Timer {
        id: ticker

        interval: 1000
        repeat: true
        running: root.timerRunning || root.swRunning
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: finishTimer

        onTriggered: {
            root.now = Date.now();
            root.remainingAtPause = 0;
            root.timerRunning = false;
            root.finished = true;

            const length = root.format(root.duration, true);
            Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-i", "alarm-timer", "Timer finished", `Your ${length} timer is done`]);
            Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/complete.oga"]);
        }
    }
}
