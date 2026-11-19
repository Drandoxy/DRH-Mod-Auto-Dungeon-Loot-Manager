package mods.auto_dungeon_loot_manager;

import mods.api.Dictionaries;

/** Local-only: use this exact native popup's registered close action, without focus. */
class LevelUpDismissal {
	var handled:Dynamic;

	public function new() {}

	public function tick(nav:Dynamic, enabled:Bool):Bool {
		if (!enabled || nav == null || nav.getTopUILayer() != "DUNGEON_SUMMARY_LEVEL_UP_POPUP") {
			handled = null;
			return false;
		}
		var callbacks:Dynamic = Reflect.field(nav, "mLayerExitCallbacks");
		var callback:Dynamic = callbacks == null ? null : Dictionaries.get(callbacks, "DUNGEON_SUMMARY_LEVEL_UP_POPUP");
		if (callback == null || !Reflect.isFunction(callback))
			return false;
		if (handled != null && Reflect.compareMethods(handled, callback))
			return false;
		handled = callback;
		Reflect.callMethod(null, callback, []);
		return true;
	}

	public function clear():Void {
		handled = null;
	}
}
