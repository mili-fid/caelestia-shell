pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.services
import qs.utils

// Spots real track changes on the player the music widget follows (Players.active), from its MPRIS
// property signals (no polling). Ignored: shell start, a player appearing (or taking over) with a song
// already loaded, pause/resume, seeking, a song looping, and metadata that is cleared and comes back.
// A late artist for the same title is a fill-in, not a new track. Empty titles and page names that some
// players report before the song's metadata arrives (Firefox: "YouTube Music") are skipped.
// On/off: "osd": { "trackChange": true } in ~/.config/caelestia/shell.json (default on).
Scope {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property bool enabled: config.enabled

    // Last real track seen on this player (what the card shows)
    property string lastTitle
    property string lastArtist

    readonly property list<string> pageTitles: ["youtube music", "youtube"]

    signal trackChanged

    function isRealTitle(title: string): bool {
        const t = title.trim().toLowerCase();
        return t !== "" && !pageTitles.includes(t);
    }

    function check(): void {
        const title = player?.trackTitle ?? "";
        const artist = player?.trackArtist ?? "";
        if (!isRealTitle(title) || (title === lastTitle && artist === lastArtist))
            return;

        const fillIn = title === lastTitle && !lastArtist;
        lastTitle = title;
        lastArtist = artist;
        if (!settling.running && !fillIn && enabled)
            trackChanged();
    }

    Component.onCompleted: {
        settling.restart();
        check();
    }

    onPlayerChanged: {
        lastTitle = "";
        lastArtist = "";
        settling.restart();
        check();
    }

    // Grace period after start / a player change: whatever arrives is the baseline, not a change
    Timer {
        id: settling

        interval: 1500
    }

    Connections {
        function onTrackTitleChanged(): void {
            root.check();
        }

        function onTrackArtistChanged(): void {
            root.check();
        }

        target: root.player
    }

    FileView {
        id: config

        readonly property bool enabled: {
            try {
                return JSON.parse(text())?.osd?.trackChange ?? true;
            } catch (e) {
                return true;
            }
        }

        path: `${Paths.config}/shell.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
}
