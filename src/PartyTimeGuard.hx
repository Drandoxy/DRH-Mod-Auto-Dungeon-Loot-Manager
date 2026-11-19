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
		var party = Type.resolveClass("mods.party_auto_join.Main");
		return party != null && Reflect.field(party, name) == true;
	}
}
