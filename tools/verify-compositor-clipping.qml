import QtQuick
import Quickshell
import "./ui" as Tahow
Scope {
    id: root
    property int phase: 0
    property int updates: 0
    function check(condition, message) {
        if (!condition) { console.error("COMPOSITOR_GEOMETRY_FAILED: " + message); Qt.exit(1); }
    }
    function near(a, b) { return Math.abs(a - b) < 0.01; }
    Window {
        id: window
        visible: true; x: 40; y: 50; width: 500; height: 300
        Item { id: alternateParent; x: 120; y: 70; transform: Translate { x: 7; y: 9 } }
        Item {
            id: viewport
            x: 30; y: 40; width: 120; height: 8; clip: true
            transform: [
                Translate { id: translation },
                Scale { id: stretch; origin.x: 60; origin.y: 4; xScale: 1; yScale: 1 }
            ]
            Tahow.CompositorGlass {
                id: glass
                x: 10; y: -20; width: 100; height: 30; radius: 15
                active: false
                onGeometryChanged: root.updates++
            }
        }
    }
    Timer {
        interval: 30; repeat: true; running: true
        onTriggered: {
            const g = glass.geometry;
            const clipOrigin = viewport.mapToGlobal(0, 0);
            const shapeOrigin = glass.mapToGlobal(0, 0);
            if (root.phase !== 5) root.check(g.supported, "translation/scale were rejected");
            if (root.phase !== 5) root.check(root.near(g.x, shapeOrigin.x) && root.near(g.y, shapeOrigin.y), "shape did not follow transform");
            if (root.phase < 4) root.check(root.near(g.clipY, clipOrigin.y), "clip origin incorrect");
            if (root.phase === 0) {
                root.check(root.near(g.width, 100) && root.near(g.height, 30), "shape was cropped instead of its scissor");
                root.check(root.near(g.clipWidth, 100) && root.near(g.clipHeight, 8), "8px notification sliver escaped clipping");
                translation.x = 35; translation.y = 11;
                root.phase = 1;
            } else if (root.phase === 1) {
                root.check(root.updates > 1, "Translate change did not notify geometry");
                root.check(root.near(g.clipHeight, 8), "translated sliver height changed");
                stretch.xScale = 0.8; stretch.yScale = 0.8;
                root.phase = 2;
            } else if (root.phase === 2) {
                root.check(root.near(g.width, 80) && root.near(g.height, 24), "Scale change did not notify geometry");
                root.check(root.near(g.clipHeight, 6.4) && root.near(g.radius, 12), "scale did not apply to clip or corner radius");
                stretch.origin.x = 20; stretch.origin.y = 0;
                root.phase = 3;
            } else if (root.phase === 3) {
                root.check(root.near(g.x, shapeOrigin.x) && root.near(g.y, shapeOrigin.y), "transform origin did not notify geometry");
                glass.y = -100;
                root.phase = 4;
            } else if (root.phase === 4) {
                root.check(g.clipHeight === 0 && !glass.ready, "fully clipped surface remained drawable");
                viewport.rotation = 15;
                root.phase = 5;
                return;
            } else if (root.phase === 5) {
                root.check(!g.supported && g.alpha === 0 && !glass.ready, "rotation did not select fallback");
                viewport.rotation = 0;
                glass.y = -20;
                viewport.parent = alternateParent;
                root.phase = 6;
            } else if (root.phase === 6) {
                root.check(g.supported, "ancestor reparent did not refresh transform references");
                root.check(root.near(g.x, shapeOrigin.x) && root.near(g.y, shapeOrigin.y), "reparented geometry stale");
                console.log("COMPOSITOR_GEOMETRY_OK clip=8px transforms=Translate,Scale,origin emptyClip=removed rotation=fallback ancestry=refreshed");
                Qt.quit();
            }
        }
    }
}
