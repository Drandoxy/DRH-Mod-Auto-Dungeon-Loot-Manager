package mods.auto_dungeon_loot_manager;

import mods.api.Context;

/** Optional same-process contract; absent or failed Party Auto Join never holds progression. */
class PartyTimeGuard {
	var context:Context;

	public function new(context:Context) {
		this.context = context;
	}

	public function active(now:Float):Bool {
		return flag("integrationWaiting");
	}

	public function autoHeld(now:Float):Bool {
		return flag("integrationHeld");
	}

	function flag(name:String):Bool {
		if (!context.isActive("party_auto_join"))
			return false;
		var layer = context.core.overlay;
		var marker = layer.getChildByName("party_auto_join_progression_hold");
		var root = layer.parent;
		if (marker == null && root != null)
			for (i in 0...root.numChildren) {
				var sibling = Std.downcast(root.getChildAt(i), openfl.display.DisplayObjectContainer);
				if (sibling == null)
					continue;
				marker = sibling.getChildByName("party_auto_join_progression_hold");
				if (marker != null)
					break;
			}
		if (marker == null) {
			// Party Auto Join 0.1.67-0.1.72 exposed the hold as static fields.
			var party = Type.resolveClass("mods.party_auto_join.Main");
			return party != null && Reflect.field(party, name) == true;
		}
		return name == "integrationWaiting" ? marker.alpha >= .99 : marker.alpha > .01;
	}
}
