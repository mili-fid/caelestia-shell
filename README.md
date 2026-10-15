# My custom desktop (caelestia-shell)

## What is this?

This is my own version of the Caelestia desktop shell: the top border, the notch that drops down, the timer, notes, music widget and popups.
It started as a copy of the normal Caelestia shell (29 September 2026), and I changed it step by step.
It lives on the PC in `~/.config/quickshell/caelestia`. **Don't move or rename anything here**: the desktop needs every file exactly where it is.

It's one of my 3 backup folders. The main guide is in [system-backup](https://github.com/mili-fid/system-backup) (open **1-START-HERE**).
My settings for this desktop (Celsius, transparency, shortcuts...) are in the other folder, [caelestia-config](https://github.com/mili-fid/caelestia-config).

## What's inside

| Folder / file | What it is |
|---|---|
| `shell.qml` | The starting point: the desktop begins here |
| `modules/` | The visible parts of the desktop, one folder each (dashboard, popups, notifications, bar...). **Most of my changes are here** |
| `services/` | The parts working in the background (music players, brightness, battery, weather...) |
| `components/` | Small shared building blocks (buttons, sliders...) |
| `utils/` | Small helper tools (icons, file paths...) |
| `assets/` | Pictures, fonts and a few helper files |
| `LICENSE` | The Caelestia license (the original authors' rules for sharing) |
| `README.md` | This guide |
| `.gitignore` | Tells git to ignore leftover files like `*.bak` |

## What I changed compared to normal Caelestia

Legend: **NEW** = file I added, **CHANGED** = original file I modified, **REMOVED** = original file I deleted.
(To see this list yourself: `git diff --stat original`)

### Top border (date, time, weather and icons along the top)
The thin frame around the screen has a taller top edge that shows information, and the old side bar is gone.

| File | | What it does |
|---|---|---|
| `modules/drawers/TopInfo.qml` | NEW | Date · time · weather in the middle of the top border |
| `modules/drawers/TopBar.qml` | NEW | Left side of the top border: power button, workspace dots, tray icons, network · Bluetooth · battery |
| `modules/drawers/ContentWindow.qml` | CHANGED | Draws the taller top border and puts every piece in its place (used by almost every feature below) |
| `modules/drawers/Drawers.qml` | CHANGED | Connects the top border to the rest |
| `modules/drawers/Exclusions.qml` | CHANGED | Windows leave room for the taller top border |
| `modules/drawers/Interactions.qml` | CHANGED | What happens on mouse hover (open the notch, the popups...) |
| `modules/drawers/Panels.qml` | CHANGED | Places the panels under the top border |
| `modules/drawers/Regions.qml` | CHANGED | Where the mouse can click through |
| `modules/bar/popouts/ClipWrapper.qml` | CHANGED | Icon popups hang down from the top border instead of sliding out from the side bar |
| `modules/bar/popouts/Wrapper.qml` | CHANGED | Same as above |

### Notch dashboard (drops down from the top when hovering)
Hovering the top shows a small notch with live tiles; clicking a tile grows it into the full dashboard.

| File | | What it does |
|---|---|---|
| `modules/dashboard/NotchMenu.qml` | NEW | The row of live tiles (one per dashboard tab, with live CPU/RAM) |
| `modules/dashboard/Wrapper.qml` | CHANGED | The notch shape and its bouncy grow/shrink animation |
| `modules/dashboard/Content.qml` | CHANGED | Which pages the dashboard has (notes, timer...) |
| `modules/Shortcuts.qml` | CHANGED | The dashboard shortcut opens the small notch first |
| `components/ScreenState.qml` | CHANGED | Remembers whether the small notch is open |
| `modules/dashboard/Dash.qml`, `Media.qml`, `Tabs.qml`, `WeatherTab.qml` | REMOVED | Old Caelestia dashboard pages, replaced by the notch |
| `modules/dashboard/dash/` (6 files) | REMOVED | Old dashboard home page (calendar, clock, user, weather...) |
| `modules/dashboard/media/` (6 files) | REMOVED | Old big music page with lyrics |

### Notes and to-do list (a dashboard tab)

| File | | What it does |
|---|---|---|
| `modules/dashboard/Notes.qml` | NEW | The Notes tab |
| `modules/dashboard/notes/NoteList.qml` | NEW | The list of notes and to-dos |
| `modules/dashboard/notes/SectionHeader.qml` | NEW | Section titles in the list |
| `modules/dashboard/notes/EmptyState.qml` | NEW | What shows when there are no notes yet |
| `modules/dashboard/notes/NotesWheelScroll.qml` | NEW | Faster, smoother scrolling with the mouse wheel and touchpad |

### Timer and stopwatch

| File | | What it does |
|---|---|---|
| `modules/dashboard/TimerTab.qml` | NEW | The Timer tab in the dashboard |
| `modules/dashboard/timer/TimerDial.qml` | NEW | The round dial |
| `modules/dashboard/timer/TimerControls.qml` | NEW | Start / pause / reset buttons and time picking |
| `modules/dashboard/timer/TimerState.qml` | NEW | Keeps the timer running even when the dashboard is closed |
| `modules/drawers/TimerPill.qml` | NEW | Small timer shown in the top border while it runs |
| `modules/drawers/TimerStrip.qml` | NEW | Thin line under the top border that shrinks as time runs out |

### Music widget (top right)

| File | | What it does |
|---|---|---|
| `modules/drawers/TopMedia.qml` | NEW | Now playing in the top border: cover, title · artist, small visualiser, previous / play-pause / next. Click the cover to play/pause; click the title · artist to bring the app that's playing to the front (switches to its workspace) |

### Track card (popup when the song changes)

| File | | What it does |
|---|---|---|
| `modules/drawers/TrackCard.qml` | NEW | Small card under the music widget showing the new song |
| `modules/drawers/TrackCardContent.qml` | NEW | What's inside the card (cover, title, artist) |
| `modules/drawers/TrackCover.qml` | NEW | The album cover picture |
| `modules/drawers/TrackCardPill.qml` | NEW | The same card as a small floating pill over fullscreen videos and games |
| `modules/drawers/TrackWatcher.qml` | NEW | Notices real song changes (ignores pause, seeking, repeats). On/off: `osd.trackChange` in shell.json |

### Volume and brightness popup (OSD)

| File | | What it does |
|---|---|---|
| `modules/osd/Wrapper.qml` | CHANGED | The popup now drops from the middle of the top border, like a notch |
| `modules/osd/Content.qml` | CHANGED | Icon, bar and percentage; scroll to change, click the icon to mute |
| `modules/osd/FloatingPill.qml` | NEW | The same popup as a floating pill over fullscreen windows |
| `modules/notifications/Content.qml` | CHANGED | Notifications no longer shrink to make room for the old side popup |

### Brightness keys

| File | | What it does |
|---|---|---|
| `services/Brightness.qml` | CHANGED | Brightness keys change by 2% per press, faster when held (fixes this laptop's keys) |

## Saved milestones (tags)

Each milestone is a named point in time I can look at or go back to:

| Name | What it is |
|---|---|
| `original` | Normal Caelestia, before any of my changes |
| `todo-list-v1` | First working to-do list |
| `top-info` | Date, time and weather in the top border |
| `timer-in-top-border` | Timer shown in the top border |
| `music-widget` | Music widget finished |
| `power-button-left` | Icons moved into the top border, power button far left, side bar removed |
| `before-notch` | The last version before the notch dashboard |
| `notch-final` | Notch dashboard finished |
| `track-card-big` | First (big) track card |
| `track-card` | Small track card, right-aligned |
| `music-source-click` | Clicking the song title in the music widget opens the app that's playing it |

On GitHub: click the **tags** button next to the branch name to see them.

## How to restore everything on a new PC

1. Follow the main guide in [system-backup → 1-START-HERE](https://github.com/mili-fid/system-backup/tree/master/1-START-HERE) up to Step 4. This installs the apps (including `quickshell-git` and `caelestia-shell`) and Caelestia.
2. Move the normal Caelestia shell out of the way:
   `mv ~/.config/quickshell/caelestia ~/.config/quickshell/caelestia.fresh`
3. Download mine:
   `git clone https://github.com/mili-fid/caelestia-shell ~/.config/quickshell/caelestia`
4. Also put back my settings ([caelestia-config](https://github.com/mili-fid/caelestia-config)). They start this desktop for me.
5. Press **Ctrl+Super+Alt+R** (or log out and back in).
6. If the plain Caelestia look appears with a "custom shell failed" message, run `qs -c caelestia` in a terminal to see why.

## How to go back to an older version

First save the current state, just in case: `backup "before going back"`.

**To just look at an old version (try it out):**

1. Open a terminal: `cd ~/.config/quickshell/caelestia`
2. See the milestones: `git tag`. Or see every saved point: `git log --oneline` (press `q` to leave the list).
3. Switch to it, for example: `git switch --detach notch-final`
4. Press **Ctrl+Super+Alt+R** to restart the desktop and see it.
5. Come back to the newest version: `git switch master`, then **Ctrl+Super+Alt+R**.
   (Don't run `backup` while trying out an old version.)

**To keep an old version for good:**

1. `cd ~/.config/quickshell/caelestia` and make sure you're on the newest one: `git switch master`
2. Bring back everything from that point: `git restore --source=notch-final --staged --worktree .`
   (Or just one file: `git restore --source=notch-final modules/drawers/TopMedia.qml`)
3. Press **Ctrl+Super+Alt+R** to check it works.
4. Save it: `backup "went back to notch-final"`. Nothing is lost: the newer versions stay in the history.

## Last big changes

- **2026-10-15**: Music widget: click the song title to jump to the app that's playing it.
- **2026-10-14**: Added this guide, milestone names (tags) and a `.gitignore`.
- **2026-10-13**: Track card: a small card under the music widget when the song changes.
- **2026-10-11**: Volume/brightness popup floats as a pill over fullscreen windows.
- **2026-10-10**: Notch dashboard with live tiles, replacing the old dashboard.
- **2026-10-10**: Icons and power button moved into the top border; side bar removed.
- **2026-10-10**: Volume/brightness popup drops from the top like a notch.
- **2026-10-10**: Music widget in the top border.
- **2026-10-06**: Timer and stopwatch, shown in the top border while running.
- **2026-09-29**: Notes and to-do list in the dashboard.
