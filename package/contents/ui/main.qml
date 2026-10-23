import QtQuick
import org.kde.kwin

Item {
    id: root

    // --- configuration -------------------------------------------------------

    // KWin.readConfig() only sees saved changes after KWin reparsed kwinrc
    // ("qdbus6 org.kde.KWin /KWin reconfigure", done by the config watcher that
    // install.sh sets up), so the values are polled instead of bound once.
    property int thickness: 4
    property int offset: 0
    property int radius: 8
    property int animation: 0
    property int duration: 3000
    property bool hideOnMaximized: false
    property var colors: ["#ff0080", "#ff8c00", "#00e5ff", "#7c4dff"]

    function loadConfig() {
        thickness = Math.max(1, KWin.readConfig("thickness", 4));
        offset = Math.max(0, KWin.readConfig("offset", 0));
        radius = Math.max(0, KWin.readConfig("radius", 8));
        animation = KWin.readConfig("animation", 0);
        duration = Math.max(200, KWin.readConfig("duration", 3000));
        hideOnMaximized = KWin.readConfig("hideOnMaximized", false);
        const newColors = [
            toColor(KWin.readConfig("color1", "#ff0080"), "#ff0080"),
            toColor(KWin.readConfig("color2", "#ff8c00"), "#ff8c00"),
            toColor(KWin.readConfig("color3", "#00e5ff"), "#00e5ff"),
            toColor(KWin.readConfig("color4", "#7c4dff"), "#7c4dff"),
        ];
        if (String(newColors) !== String(colors)) {
            colors = newColors;
        }
    }

    Component.onCompleted: {
        loadConfig();
        for (const w of Workspace.stackingOrder) {
            watchGeometry(w);
        }
        track(Workspace.activeWindow);
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.loadConfig()
    }

    function toColor(value, fallback) {
        const text = String(value).trim();
        // KConfig stores colors as "r,g,b[,a]"
        const rgb = text.match(/^(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*(\d+))?$/);
        if (rgb) {
            const a = rgb[4] === undefined ? 255 : Number(rgb[4]);
            return Qt.rgba(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, a / 255);
        }
        const hex = text.startsWith("#") ? text : "#" + text;
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : fallback;
    }

    // --- target window -------------------------------------------------------

    // Nothing here is bound to KWin's window objects. When KWin shuts down it
    // destroys windows and activates the next one synchronously, while its
    // renderer is already gone; touching windows or resizing the strips at that
    // point crashes KWin. So signals only schedule update() via Qt.callLater(),
    // which runs on the next event loop iteration - one that never comes
    // during shutdown.

    // Plain JS holder, so that a destroyed window never triggers bindings.
    readonly property var tracked: ({ window: null })

    property bool active: false
    // Ring geometry in global (logical) coordinates.
    property rect ring: Qt.rect(0, 0, 0, 0)
    // Geometries of windows stacked above the active one (menus, tooltips,
    // notifications, panels, keep-above windows). The border itself is drawn
    // above everything, so the strips cut these areas out.
    property var obstacles: []

    function isCandidate(w) {
        if (!w || w.deleted || w.minimized || w.fullScreen || w.hidden) {
            return false;
        }
        if (!w.normalWindow && !w.dialog) {
            return false;
        }
        if (hideOnMaximized) {
            const area = Workspace.clientArea(Workspace.MaximizeArea, w.output, Workspace.currentDesktop);
            const g = w.frameGeometry;
            if (g.x <= area.x && g.y <= area.y
                    && g.x + g.width >= area.x + area.width
                    && g.y + g.height >= area.y + area.height) {
                return false;
            }
        }
        return true;
    }

    function isOnCurrentDesktop(w) {
        const desktops = w.desktops;
        if (w.onAllDesktops || desktops.length === 0) { // popups have no desktop
            return true;
        }
        // Desktops arrive as fresh wrappers, so compare ids instead of objects.
        const current = Workspace.currentDesktop.id;
        for (let i = 0; i < desktops.length; i++) {
            if (desktops[i].id === current) {
                return true;
            }
        }
        return false;
    }

    function isVisibleHere(w) {
        return !w.minimized && !w.hidden && !w.deleted && w.caption !== stripTitle
            && isOnCurrentDesktop(w);
    }

    function windowsAbove(w) {
        const order = Workspace.stackingOrder;
        const index = order.indexOf(w);
        return index < 0 ? [] : order.slice(index + 1).filter(isVisibleHere);
    }

    function update() {
        const w = tracked.window;
        if (!isCandidate(w)) {
            active = false;
            return;
        }
        obstacles = windowsAbove(w).map(o => {
            const g = o.frameGeometry;
            return Qt.rect(g.x, g.y, g.width, g.height);
        });
        const g = w.frameGeometry;
        const grow = offset + thickness;
        ring = Qt.rect(g.x - grow, g.y - grow, g.width + 2 * grow, g.height + 2 * grow);
        active = true;
    }

    function scheduleUpdate() {
        Qt.callLater(update);
    }

    // Any window moving may start or stop covering the border.
    function watchGeometry(w) {
        if (w.caption !== stripTitle) {
            w.frameGeometryChanged.connect(scheduleUpdate);
        }
    }

    function track(w) {
        const old = tracked.window;
        if (old === w) {
            return;
        }
        if (old) {
            try {
                old.fullScreenChanged.disconnect(scheduleUpdate);
                old.minimizedChanged.disconnect(scheduleUpdate);
            } catch (e) {
                // already destroyed, its connections are gone with it
            }
        }
        tracked.window = w;
        if (w) {
            w.fullScreenChanged.connect(scheduleUpdate);
            w.minimizedChanged.connect(scheduleUpdate);
            fadeIn.restart();
        }
        scheduleUpdate();
    }

    Connections {
        target: Workspace
        function onWindowActivated(w) {
            root.track(w);
        }
        function onWindowAdded(w) {
            root.hideFromSwitchers(w);
            root.watchGeometry(w);
        }
        function onWindowRemoved(w) {
            if (w === root.tracked.window) {
                root.tracked.window = null;
            }
            root.scheduleUpdate();
        }
        function onStackingOrderChanged() {
            root.scheduleUpdate();
        }
        function onCurrentDesktopChanged() {
            root.scheduleUpdate();
        }
    }

    onThicknessChanged: scheduleUpdate()
    onOffsetChanged: scheduleUpdate()
    onHideOnMaximizedChanged: scheduleUpdate()

    readonly property real innerRadius: radius > 0 ? radius + offset : 0
    readonly property real outerRadius: innerRadius > 0 ? innerRadius + thickness : 0

    // How deep the top/bottom strips reach, so they include the rounded corners.
    readonly property real band: Math.min(thickness + innerRadius, ring.height / 2)

    // See BorderStrip: windows may only be shown after the script has loaded.
    property bool ready: false
    Timer {
        interval: 100
        running: true
        onTriggered: root.ready = true
    }

    // --- animation -----------------------------------------------------------

    property real angle: 0
    property real pulse: 1
    property real fade: 1

    NumberAnimation on angle {
        running: root.active && (root.animation === 0 || root.animation === 1)
        from: root.animation === 1 ? 360 : 0
        to: root.animation === 1 ? 0 : 360
        duration: root.duration
        loops: Animation.Infinite
    }

    SequentialAnimation on pulse {
        running: root.active && root.animation === 2
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: root.duration / 2; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: root.duration / 2; easing.type: Easing.InOutSine }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "fade"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    // --- keep the strips out of Overview, task switcher and taskbar ---------

    readonly property string stripTitle: "animatedborders-strip"

    function hideFromSwitchers(w) {
        if (w.caption === stripTitle) {
            w.skipPager = true;
            w.skipSwitcher = true;
            w.skipTaskbar = true;
        }
    }

    // --- the four edges ------------------------------------------------------

    BorderStrip {
        border: root
        area: Qt.rect(root.ring.x, root.ring.y, root.ring.width, root.band)
    }
    BorderStrip {
        border: root
        area: Qt.rect(root.ring.x, root.ring.y + root.ring.height - root.band, root.ring.width, root.band)
    }
    BorderStrip {
        border: root
        area: Qt.rect(root.ring.x, root.ring.y + root.band, root.thickness, root.ring.height - 2 * root.band)
    }
    BorderStrip {
        border: root
        area: Qt.rect(root.ring.x + root.ring.width - root.thickness, root.ring.y + root.band, root.thickness, root.ring.height - 2 * root.band)
    }
}
