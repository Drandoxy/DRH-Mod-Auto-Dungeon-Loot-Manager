package mods.auto_dungeon_loot_manager;

import brain.assetRepository.SwfAsset;
import brain.uI.UIButton;
import brain.uI.UIObject;
import dBGlobals.DBGlobal;
import facade.DBFacade;
import openfl.display.MovieClip;

/** A third native button in the existing confirmation popup. */
class ExitControls {
    var facade:DBFacade;
    var popup:Dynamic;
    var restart:UIButton;
    var neighbor:UIButton;
    var oldRight:UIObject;
    var oldDown:UIObject;
    var upper:UIButton;
    var lower:UIButton;
    var upperMatrix:openfl.geom.Matrix;
    var lowerMatrix:openfl.geom.Matrix;
    var root:MovieClip;
    var enabled:Bool = true;

    public static function find(facade:DBFacade):Dynamic {
        if (facade == null || facade.hud == null) return null;
        var hud:Dynamic = facade.hud;
        var popup = Reflect.field(hud, "mLootLossPopup");
        if (popup == null) popup = Reflect.field(hud, "mInfiniteExitPopup");
        return popup;
    }
    public function new(facade:DBFacade, popup:Dynamic, onRestart:Void->Void, title:String = "") {
        this.facade = facade;
        this.popup = popup;
        var art:SwfAsset = cast Reflect.field(popup, "mSwfAsset");
        var parent:MovieClip = cast Reflect.field(popup, "mPopup");
        var left:UIButton = cast Reflect.field(popup, "mLeftButton");
        var right:UIButton = cast Reflect.field(popup, "mRightButton");
        if (art == null || parent == null || left == null || right == null) return;
        if (title != "") {
            var heading:openfl.text.TextField = cast Reflect.field(popup, "mTitle");
            if (heading != null) {
                brain.utils.TextUtil.setText(heading, title);
                // Preserve the native font and effects, fitting longer dungeon names.
                if (heading.textWidth > heading.width - 8) {
                    var format = heading.getTextFormat();
                    var size:Float = format.size;
                    format.size = Math.max(12, Math.floor(size * (heading.width - 8) / heading.textWidth));
                    heading.setTextFormat(format);
                }
            }
        }
        var infinite = Reflect.field(facade.hud, "mInfiniteExitPopup") == popup;
        var symbol = infinite ? "exitdungeon_infinite_popup" : "exitdungeon_popup";
        var fresh:MovieClip = cast art.instantiateRuntimeSymbol(symbol, []);
        root = cast NativeButton.child(fresh, "left_button");
        if (root == null) throw "Native exit button artwork not found";
        root.parent.removeChild(root);
        NativeButton.stop(root);
        NativeButton.label(root, "RESTART", true);
        root.name = "auto_dungeon_loot_manager_button";
        parent.addChild(root);
        root.transform.matrix = left.root.transform.matrix.clone();
        var a = left.root.getBounds(parent);
        var b = right.root.getBounds(parent);
        var bounds = root.getBounds(parent);
        var last = Math.max(a.right, b.right);
        var gap = Math.max(8, Math.abs(a.x - b.x) - a.width);
        root.x += last + gap - bounds.x;
        root.y += a.y - bounds.y;
        restart = new UIButton(facade, root);
        restart.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
        restart.releaseCallback = onRestart;
        if (infinite) {
            upper = a.y < b.y ? left : right;
            lower = upper == left ? right : left;
            upperMatrix = upper.root.transform.matrix.clone();
            lowerMatrix = lower.root.transform.matrix.clone();
            var top = Math.min(a.top, b.top);
            var height = Math.max(a.bottom, b.bottom) - top;
            var gapY = height * 0.04;
            var row = (height - 2 * gapY) / 3;
            var center = (a.x + a.width / 2 + b.x + b.width / 2) / 2;
            placeStackButton(upper.root, parent, center, top, row);
            placeStackButton(lower.root, parent, center, top + row + gapY, row);
            placeStackButton(root, parent, center, top + 2 * (row + gapY), row);
            neighbor = lower;
            oldDown = lower.downNavigation;
            lower.clearDownNavigation();
            lower.downNavigation = restart;
            restart.upNavigation = lower;
            return;
        }
        neighbor = a.x > b.x ? left : right;
        oldRight = neighbor.rightNavigation;
        neighbor.clearRightNavigation();
        neighbor.rightNavigation = restart;
        restart.leftNavigation = neighbor;
        restart.upNavigation = cast Reflect.field(popup, "mCloseButton");
    }
    static function placeStackButton(button:MovieClip, parent:MovieClip, center:Float, top:Float, height:Float):Void {
        var bounds = button.getBounds(parent);
        var scale = Math.min(1, height / bounds.height);
        button.scaleX *= scale;
        button.scaleY *= scale;
        bounds = button.getBounds(parent);
        button.x += center - bounds.x - bounds.width / 2;
        button.y += top + (height - bounds.height) / 2 - bounds.y;
    }

    public function matches(value:Dynamic):Bool {
        return value == popup && root != null && Reflect.field(popup, "mPopup") != null;
    }
    public function update(available:Bool):Void {
        if (restart != null && enabled != available) {
            enabled = available;
            restart.enabled = available;
            root.alpha = available ? 1 : 0.5;
        }
    }
    public function destroy():Void {
        if (lower != null && lower.root != null) {
            if (lower.downNavigation == restart) {
                lower.clearDownNavigation();
                if (oldDown != null && oldDown.root != null) lower.downNavigation = oldDown;
            }
            lower.root.transform.matrix = lowerMatrix;
        }
        if (upper != null && upper.root != null) upper.root.transform.matrix = upperMatrix;
        if (neighbor != null && neighbor.root != null && neighbor.rightNavigation == restart) {
            neighbor.clearRightNavigation();
            if (oldRight != null && oldRight.root != null) neighbor.rightNavigation = oldRight;
        }
        if (restart != null && restart.isFocused() && neighbor != null && neighbor.root != null)
            facade.menuNavigationController.setFocusedUiObject(neighbor);
        if (root != null) NativeButton.forget(root);
        if (root != null && root.parent != null) root.parent.removeChild(root);
        if (restart != null) restart.destroy();
        restart = null; neighbor = null; oldRight = null; root = null; popup = null; facade = null;
    }
}
