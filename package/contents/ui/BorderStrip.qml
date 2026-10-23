import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Window

// One edge of the border. The ring is split into four thin windows so the
// compositor only repaints the edges, not the whole area of the active window.
// Every strip draws the complete ring, shifted so only its own part is visible.
Window {
    id: strip

    required property Item border
    property rect area

    // Tells KWin this internal window never takes pointer input.
    property bool outputOnly: true

    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
         | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: border.stripTitle

    x: area.x
    y: area.y
    width: Math.max(1, area.width)
    height: Math.max(1, area.height)

    // Setting "visible" has no effect on windows declared inside a KWin script,
    // only show()/hide() do, and only after the script has finished loading.
    readonly property bool shown: border.ready && border.active && area.width > 0 && area.height > 0
    onShownChanged: shown ? show() : hide()

    // Menus, tooltips and panels overlapping this strip, in strip coordinates.
    // The border is drawn above every window, so these areas are cut out to make
    // such windows look like they are on top of it.
    readonly property var holes: border.obstacles
        .filter(o => o.x < area.x + area.width && o.x + o.width > area.x
                  && o.y < area.y + area.height && o.y + o.height > area.y)
        .map(o => Qt.rect(o.x - area.x, o.y - area.y, o.width, o.height))

    Item {
        id: holeMask
        anchors.fill: parent
        visible: false
        layer.enabled: strip.holes.length > 0

        Repeater {
            model: strip.holes
            Rectangle {
                required property rect modelData
                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                color: "black"
            }
        }
    }

    Item {
        anchors.fill: parent
        // Only pay for the offscreen layer while something overlaps.
        layer.enabled: strip.holes.length > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: holeMask
        }

        Shape {
            id: shape

            x: strip.border.ring.x - strip.area.x
            y: strip.border.ring.y - strip.area.y
            width: strip.border.ring.width
            height: strip.border.ring.height
            opacity: strip.border.fade * strip.border.pulse
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                fillGradient: ConicalGradient {
                    centerX: shape.width / 2
                    centerY: shape.height / 2
                    angle: strip.border.angle

                    GradientStop { position: 0.0;  color: strip.border.colors[0] }
                    GradientStop { position: 0.25; color: strip.border.colors[1] }
                    GradientStop { position: 0.5;  color: strip.border.colors[2] }
                    GradientStop { position: 0.75; color: strip.border.colors[3] }
                    GradientStop { position: 1.0;  color: strip.border.colors[0] }
                }

                PathRectangle {
                    width: shape.width
                    height: shape.height
                    radius: strip.border.outerRadius
                }
                PathRectangle {
                    x: strip.border.thickness
                    y: strip.border.thickness
                    width: shape.width - 2 * strip.border.thickness
                    height: shape.height - 2 * strip.border.thickness
                    radius: strip.border.innerRadius
                }
            }
        }
    }
}
