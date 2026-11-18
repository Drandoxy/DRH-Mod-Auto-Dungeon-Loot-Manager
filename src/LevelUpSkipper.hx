package mods.auto_dungeon_loot_manager;

import facade.DBFacade;
import brain.uI.UIObject;
import brain.uI.UIButton;

/** Acknowledge only the native level-up Sweet button, once per popup. */
class LevelUpSkipper {
	var handled:UIButton;

	public function new() {}

	public function destroy():Void {
		handled = null;
	}

	public function tick(facade:DBFacade, enabled:Bool):Void {
		var nav = facade.menuNavigationController;
		if (!enabled || nav == null || nav.getTopUILayer() != "DUNGEON_SUMMARY_LEVEL_UP_POPUP") {
			handled = null;
			return;
		}
		var focused:UIObject = nav.focusedUiObject;
		if (focused == null)
			return;
		var queue:Array<UIObject> = [focused];
		var seen:Array<UIObject> = [];
		while (queue.length > 0 && seen.length < 12) {
			var current:UIObject = queue.shift();
			if (current == null || seen.indexOf(current) >= 0)
				continue;
			seen.push(current);
			var button = Std.downcast(current, UIButton);
			if (button != null && button.root != null && button.root.name == "share") {
				if (button != handled && button.enabled && button.root.visible && button.root.stage != null && button.releaseCallback != null) {
					handled = button;
					button.releaseCallback();
				}
				return;
			}
			for (next in [
				current.leftNavigation,
				current.rightNavigation,
				current.upNavigation,
				current.downNavigation
			])
				if (next != null && seen.indexOf(next) < 0)
					queue.push(next);
		}
	}
}
