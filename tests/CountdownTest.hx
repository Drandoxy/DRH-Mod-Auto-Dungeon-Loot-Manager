import mods.auto_dungeon_loot_manager.RestartCountdown;
class CountdownTest {
    static var checks = 0;
    static function check(b:Bool, s:String) { checks++; if (!b) throw s; }
    static function main() {
        var c = new RestartCountdown();
        check(!c.tick(0,true,false,6), "unsettled loot cannot start countdown");
        check(c.due == -1, "no deadline before rewards settle");
        check(!c.tick(1000,true,true,6), "six-second default does not fire early");
        check(c.remaining(1000)==6, "initial countdown label");
        check(!c.tick(6999,true,true,6), "wait full six seconds");
        check(c.tick(7000,true,true,6), "fire at six seconds");
        check(!c.tick(8000,true,true,6), "one restart per summary");
        for (action in ["Next", "Restart", "Exit"]) {
            c.reset(); c.tick(0,true,true,6); c.cancel();
            check(!c.tick(10000,true,true,6), action+" cancels pending restart");
            check(c.remaining(10000)==-1, action+" hides countdown");
        }
        c.reset(); check(c.tick(0,true,true,0), "zero fires once rewards settle");
        c.reset(); c.tick(0,true,true,10);
        check(!c.tick(9999,true,true,10), "ten-second maximum waits");
        check(c.tick(10000,true,true,10), "ten-second maximum fires");
        c.reset(); c.tick(0,true,true,6); c.tick(3000,true,false,6);
        check(c.due==-1, "new modal pauses and clears the clock");
        check(!c.tick(10000,true,true,6), "settling restarts a full delay");
        c.tick(10001,false,true,6); check(c.due==-1,"disabled means no deadline");
        c.reset(); c.tick(0,true,true,6); c.tick(1000,true,true,2);
        check(c.due==3000, "changing delay restarts the deadline");
        Sys.println("Countdown: "+checks+" checks passed");
    }
}
