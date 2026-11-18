package mods.auto_dungeon_loot_manager;

/** Optional local Party Time integration. Expiring heartbeat cannot keep Auto Dungeon paused after a crash. */
class PartyTimeGuard {
	var path:String;
	var next = 0.;
	var waiting = false;
	var held = false;

	public function new(data:String) {
		path = data + "/../party_time_auto_game_joiner/waiting.json";
	}

	public function autoHeld(now:Float):Bool {
		active(now);
		return held;
	}

	public function active(now:Float):Bool {
		if (now < next)
			return waiting;
		next = now + 200;
		waiting = false;
		held = false;
		try {
			if (sys.FileSystem.exists(path)) {
				var d = haxe.Json.parse(sys.io.File.getContent(path));
				var fresh = Date.now().getTime() - d.time < 3000;
				waiting = d.waiting == true && fresh;
				held = d.autoHold == true && fresh;
			}
		} catch (_:Dynamic) {}
		return waiting;
	}
}
