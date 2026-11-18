package mods.auto_dungeon_loot_manager;

import facade.DBFacade;
import brain.uI.UIObject;
import brain.uI.UIButton;
import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import openfl.display.MovieClip;

/** Finds the death-flow confirmation through the native navigation graph.
	That popup is local to ActorReviveState and has no retained HUD reference. */
class ExitPopupFinder {
	var facade:DBFacade;
	var assets:AssetLoadingComponent;
	var art:SwfAsset;
	var proxy:Dynamic;
	var dead = false;

	public function new(facade:DBFacade) {
		this.facade = facade;
	}

	public function find():Dynamic {
		var hudPopup = ExitControls.find(facade);
		var nav = facade.menuNavigationController;
		if (nav == null || nav.getTopUILayer() != "EXIT_DUNGEON") {
			proxy = null;
			return hudPopup;
		}
		var focused:UIObject = nav.focusedUiObject;
		if (focused == null || focused.root == null)
			return hudPopup;
		if (proxy != null) {
			var root:MovieClip = cast proxy.mPopup;
			if (root != null && root.stage != null && focused.root.parent == root)
				return proxy;
			proxy = null;
		}
		if (hudPopup != null) {
			var root:MovieClip = cast Reflect.field(hudPopup, "mPopup");
			if (root != null && focused.root.parent == root)
				return hudPopup;
		}
		var queue:Array<UIObject> = [focused];
		var visited:Array<UIObject> = [];
		var left:UIButton = null;
		var right:UIButton = null;
		var close:UIButton = null;
		// Only this small native dialog's navigation graph, never the scene tree.
		while (queue.length > 0 && visited.length < 12) {
			var current:UIObject = queue.shift();
			if (current == null || visited.indexOf(current) >= 0)
				continue;
			visited.push(current);
			var button = Std.downcast(current, UIButton);
			if (button != null && button.root != null) {
				if (button.root.name == "left_button")
					left = button;
				if (button.root.name == "right_button")
					right = button;
				if (button.root.name == "close_button")
					close = button;
			}
			for (next in [
				current.leftNavigation,
				current.rightNavigation,
				current.upNavigation,
				current.downNavigation
			])
				if (next != null && visited.indexOf(next) < 0)
					queue.push(next);
		}
		if (left == null || right == null || left.root.parent != right.root.parent)
			return null;
		var parent:MovieClip = Std.downcast(left.root.parent, MovieClip);
		if (parent == null || parent.getChildByName("XP_amount") == null)
			return null;
		if (art == null) {
			if (assets == null) {
				assets = new AssetLoadingComponent(facade);
				assets.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_screens.swf"), function(value:SwfAsset) {
					if (!dead)
						art = value;
				});
			}
			if (art == null)
				return null;
		}
		// Cancel closes this exact native popup before the normal exit request.
		var cancel = right.releaseCallback;
		proxy = {
			mPopup: parent,
			mSwfAsset: art,
			mTitle: parent.getChildByName("title_label"),
			mLeftButton: left,
			mRightButton: right,
			mCloseButton: close,
			destroy: function() {
				if (cancel != null)
					cancel();
			}
		};
		return proxy;
	}

	public function destroy():Void {
		dead = true;
		if (assets != null)
			assets.destroy();
		assets = null;
		art = null;
		proxy = null;
		facade = null;
	}
}
