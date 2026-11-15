package mods.auto_dungeon_loot_manager;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import brain.sceneGraph.SceneGraphManager;
import brain.uI.UIButton;
import brain.uI.UIObject;
import dBGlobals.DBGlobal;
import facade.DBFacade;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/** Native primary navigation target and a second animated button below it. */
class SummaryControls {
    var facade:DBFacade;
    var summary:Dynamic;
    var assets:AssetLoadingComponent;
    var art:SwfAsset;
    var primary:UIButton;
    var secondary:UIButton;
    var wrapper:MovieClip;
    var originalWrapper:MovieClip;
    var originalAction:Dynamic;
    var primaryAction:Dynamic;
    var oldDown:UIObject;
    var onRestart:Void->Void;
    var beforeNext:Void->Void;
    var onManualExit:Void->Void;
    var headerExit:UIButton;
    var headerAction:Dynamic;
    var headerWrapper:Dynamic;
    var dead:Bool = false;
    var swapped:Null<Bool> = null;
    var originalText:String = "NEXT";
    var label:TextField;
    var countdownPanel:Sprite;
    var caption:String = "";
    var options:AutoOptions;

    public function new(facade:DBFacade, summary:Dynamic, options:AutoOptions,
        onRestart:Void->Void, beforeNext:Void->Void, onManualExit:Void->Void) {
        this.facade = facade; this.summary = summary; this.options = options;
        this.onRestart = onRestart; this.beforeNext = beforeNext; this.onManualExit = onManualExit;
        assets = new AssetLoadingComponent(facade);
        assets.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_score_report.swf"),
            function(value:SwfAsset) { if (!dead) art = value; });
    }
    public function update(available:Bool):Void {
        if (dead) return;
        var section:Dynamic = Reflect.field(summary, "mNextFloorSection");
        if (section == null) return;
        if (primary == null) {
            primary = cast Reflect.field(section, "mBattleButton");
            if (primary == null || primary.root == null) { primary = null; return; }
            originalAction = primary.releaseCallback;
            var mode = Std.string(Reflect.field(section, "mTypeOfPopup"));
            originalText = mode == "VICTORY" ? "NEXT" : "RETRY";
        }
        if (wrapper == null && art != null) build();
        if (wrapper == null || originalWrapper.parent == null) return;
        applySwap(options.swap.value == "yes");
        if (primary.downNavigation != secondary) {
            primary.clearDownNavigation(); primary.downNavigation = secondary;
        }
        wrapper.visible = originalWrapper.visible && Reflect.field(summary, "mLeaving") != true;
        if (primary.enabled != available || secondary.enabled != available) {
            primary.enabled = available; secondary.enabled = available;
            primary.root.filters = available ? [] : [SceneGraphManager.getGrayScaleSaturationFilter(5)];
            secondary.root.filters = available ? [] : [SceneGraphManager.getGrayScaleSaturationFilter(5)];
        }
        hookExit();
        if (countdownPanel != null) countdownPanel.visible = wrapper.visible && caption != "";
    }
    function hookExit():Void {
        if (headerExit != null) return;
        var header:Dynamic = Reflect.field(summary, "mTownHeader");
        if (header == null) return;
        headerExit = cast header.closeButton;
        if (headerExit == null) return;
        headerAction = headerExit.releaseCallback;
        headerWrapper = function() {
            onManualExit();
            if (headerAction != null) Reflect.callMethod(headerExit, headerAction, []);
        };
        headerExit.releaseCallback = headerWrapper;
    }
    public function autoNext():Bool {
        if (dead || primary == null || wrapper == null || originalAction == null || !primary.enabled) return false;
        runNext();
        return true;
    }
    function runNext():Void {
        beforeNext();
        if (originalAction != null) Reflect.callMethod(primary, originalAction, []);
    }
    function applySwap(value:Bool):Void {
        if (swapped == value) return;
        swapped = value;
        primaryAction = value ? function() { onRestart(); } : function() { runNext(); };
        primary.releaseCallback = primaryAction;
        secondary.releaseCallback = value ? function() { runNext(); } : function() { onRestart(); };
        NativeButton.label(originalWrapper, value ? "RESTART" : originalText, true);
        NativeButton.label(wrapper, value ? originalText : "RESTART", true);
    }
    function build():Void {
        var report:MovieClip = cast Reflect.field(summary, "mScoreReportRoot");
        var popup = NativeButton.child(report, "dungeon_popup");
        originalWrapper = cast NativeButton.child(popup, "button_center");
        if (originalWrapper == null || originalWrapper.parent == null) return;
        var fresh:MovieClip = cast art.instantiateRuntimeSymbol("DRfriends_UI_score_report", []);
        wrapper = cast NativeButton.child(NativeButton.child(fresh, "dungeon_popup"), "button_center");
        if (wrapper == null) throw "Native score report button not found";
        wrapper.parent.removeChild(wrapper);
        wrapper.name = "auto_dungeon_loot_manager_secondary";
        originalWrapper.parent.addChild(wrapper);
        wrapper.transform.matrix = originalWrapper.transform.matrix.clone();
        var parent = originalWrapper.parent;
        var a = originalWrapper.getBounds(parent);
        var b = wrapper.getBounds(parent);
        wrapper.x += a.x + a.width * 0.5 - b.x - b.width * 0.5;
        wrapper.y += a.bottom + 6 - b.top;
        // UIButton owns the same up/over/down/selected MovieClip renderers as
        // the original; don't replace it with a static drawing or stop its clips.
        secondary = new UIButton(facade, wrapper);
        secondary.rolloverFilter = primary.rolloverFilter == null ? DBGlobal.UI_ROLLOVER_FILTER : primary.rolloverFilter;
        secondary.selectedFilter = primary.selectedFilter;
        secondary.navigationSelectedInteraction = function() { DBGlobal.highlightButton(secondary); };
        secondary.navigationSetToUnselectedInteraction = function() { DBGlobal.unHighlightButton(secondary); };
        oldDown = primary.downNavigation;
        secondary.upNavigation = primary;
        // Reuse the rewards board itself from a fresh native symbol. The
        // countdown sits above the complete board/ribbon rather than over XP.
        var panelSource:MovieClip = cast NativeButton.child(fresh, "dungeon_popup");
        var background:DisplayObject = panelSource.getChildAt(0);
        var boardBounds = (cast popup:MovieClip).getChildAt(0).getBounds(parent);
        var wholeBounds = (cast popup:MovieClip).getBounds(parent);
        countdownPanel = new Sprite();
        countdownPanel.mouseEnabled = false;
        countdownPanel.mouseChildren = false;
        panelSource.removeChild(background);
        countdownPanel.addChild(background);
        var local = background.getBounds(countdownPanel);
        // A nine-slice grid keeps the native metal corners and wooden edges
        // while reducing just the middle of the panel vertically.
        var skin:Sprite = Std.downcast(background, Sprite);
        if (skin != null) {
            var own = skin.getBounds(skin);
            var inset = Math.min(14, Math.min(own.width, own.height) / 4);
            skin.scale9Grid = new Rectangle(own.x + inset, own.y + inset,
                own.width - inset * 2, own.height - inset * 2);
        }
        background.height = 54;
        background.width = boardBounds.width;
        local = background.getBounds(countdownPanel);
        background.x -= local.x;
        background.y -= local.y;
        countdownPanel.x = boardBounds.x;
        countdownPanel.y = wholeBounds.top - 65;
        label = new TextField();
        var template:TextField = cast NativeButton.child(popup, "text_victorRewards");
        var format = template == null ? new TextFormat("Fat Rhino PB", 16, 0xFFCC00) : template.getTextFormat();
        format.align = TextFormatAlign.CENTER;
        label.defaultTextFormat = format;
        if (template != null) {
            label.embedFonts = template.embedFonts;
            label.filters = template.filters;
        }
        label.width = boardBounds.width - 16;
        label.height = 36;
        label.x = 8;
        label.selectable = false;
        label.mouseEnabled = false;
        label.wordWrap = false;
        countdownPanel.addChild(label);
        parent.addChild(countdownPanel);
        label.text = caption.toUpperCase();
        label.y = (54 - label.textHeight) * 0.5 - 2;
        countdownPanel.visible = caption != "";
        primary.enabled = false; secondary.enabled = false;
    }
    public function status(text:String):Void {
        if (caption == text) return;
        caption = text;
        if (label != null) {
            label.text = text.toUpperCase();
            label.y = (54 - label.textHeight) * 0.5 - 2;
        }
        if (countdownPanel != null) countdownPanel.visible = text != "";
    }
    public function destroy():Void {
        if (dead) return;
        dead = true;
        if (headerExit != null && headerExit.root != null && Reflect.compareMethods(headerExit.releaseCallback, headerWrapper))
            headerExit.releaseCallback = headerAction;
        if (primary != null && primary.root != null) {
            if (Reflect.compareMethods(primary.releaseCallback, primaryAction)) {
                primary.releaseCallback = originalAction;
                NativeButton.label(primary.root, originalText);
            }
            if (primary.downNavigation == secondary) {
                primary.clearDownNavigation();
                if (oldDown != null && oldDown.root != null) primary.downNavigation = oldDown;
            }
            if (secondary != null && secondary.isFocused()) facade.menuNavigationController.setFocusedUiObject(primary);
        }
        if (originalWrapper != null) NativeButton.forget(originalWrapper);
        if (wrapper != null) NativeButton.forget(wrapper);
        if (countdownPanel != null && countdownPanel.parent != null) countdownPanel.parent.removeChild(countdownPanel);
        if (wrapper != null && wrapper.parent != null) wrapper.parent.removeChild(wrapper);
        if (secondary != null) secondary.destroy();
        if (assets != null) assets.destroy();
        secondary = null; primary = null; wrapper = null; originalWrapper = null;
        summary = null; art = null; facade = null; label = null; countdownPanel = null; options = null;
        headerExit = null; headerAction = null; headerWrapper = null;
    }
}
