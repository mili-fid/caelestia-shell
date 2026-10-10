import QtQuick

// Faster wheel/touchpad scrolling for the Notes tab flickables.
// Mouse wheel: each notch eases by `step` px. Touchpad: deltas are scaled by
// `touchpadMultiplier`, and lifting the fingers hands the swipe speed to a
// kinetic flick so fast swipes keep coasting.
WheelHandler {
    id: root

    required property Flickable flickable
    property real step: 60
    property real touchpadMultiplier: 2.5

    property real _targetY
    property var _samples: []

    function _minY(): real {
        return flickable.originY - flickable.topMargin;
    }

    function _maxY(): real {
        return Math.max(_minY(), flickable.originY + flickable.contentHeight + flickable.bottomMargin - flickable.height);
    }

    function _clamp(y: real): real {
        return Math.max(_minY(), Math.min(_maxY(), y));
    }

    parent: flickable
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        const touchpad = event.phase !== Qt.NoScrollPhase || (event.pixelDelta.y !== 0 && event.angleDelta.y % 120 !== 0);

        if (!touchpad) {
            if (event.angleDelta.y === 0)
                return;
            flickable.cancelFlick();
            const from = anim.running ? _targetY : flickable.contentY;
            _targetY = _clamp(from - event.angleDelta.y / 120 * step);
            anim.to = _targetY;
            anim.restart();
            return;
        }

        anim.stop();
        const now = Date.now();

        if (event.phase === Qt.ScrollBegin) {
            flickable.cancelFlick();
            _samples = [];
        }

        const dy = (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8) * touchpadMultiplier;
        if (dy !== 0) {
            flickable.contentY = _clamp(flickable.contentY - dy);
            _samples.push({
                t: now,
                dy
            });
            _samples = _samples.filter(s => now - s.t < 100);
        }

        if (event.phase === Qt.ScrollEnd) {
            const recent = _samples.filter(s => now - s.t < 100);
            _samples = [];
            if (recent.length > 1) {
                const span = Math.max(16, now - recent[0].t);
                const dist = recent.reduce((sum, s) => sum + s.dy, 0);
                const velocity = dist / span * 1000;
                if (Math.abs(velocity) > 300)
                    flickable.flick(0, velocity);
            }
        }
    }

    property NumberAnimation _anim: NumberAnimation {
        id: anim

        target: root.flickable
        property: "contentY"
        duration: 180
        easing.type: Easing.OutCubic
    }
}
