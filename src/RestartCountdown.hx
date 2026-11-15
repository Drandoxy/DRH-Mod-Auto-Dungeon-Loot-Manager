package mods.auto_dungeon_loot_manager;

/** One countdown per summary; manual input cancels it until the next run. */
class RestartCountdown {
    public var cancelled(default, null):Bool = false;
    public var due(default, null):Float = -1;
    public var fired(default, null):Bool = false;
    var delay:Int = -1;
    public function new() {}
    public function reset():Void { cancelled = false; due = -1; fired = false; delay = -1; }
    public function cancel():Void { cancelled = true; due = -1; }
    public function tick(now:Float, enabled:Bool, settled:Bool, seconds:Int):Bool {
        if (cancelled || fired) return false;
        if (!enabled || !settled) { due = -1; return false; }
        seconds = seconds < 0 ? 0 : (seconds > 10 ? 10 : seconds);
        if (due < 0 || delay != seconds) { delay = seconds; due = now + seconds * 1000; }
        if (now < due) return false;
        fired = true;
        return true;
    }
    public function remaining(now:Float):Int {
        return due < 0 || cancelled || fired ? -1 : Std.int(Math.max(0, Math.ceil((due - now) / 1000)));
    }
}
