import mods.auto_dungeon_loot_manager.RewardFlow;
import mods.auto_dungeon_loot_manager.AutoOptions;
import mods.api.Context;
import facade.DBFacade;
import brain.workLoop.WorkComponent;
import openfl.display.DisplayObjectContainer;

/**
 * The game's reveal from the kill count on, its tasks run by the work loop at
 * 200 FPS, while the chest artwork loads late. Each guard that waited for it
 * has run and stays in the summary's tasks until a collection, as in the game.
 */
class FiredRevealTaskTest {
	static var checks = 0;

	static function check(b:Bool, s:String) {
		checks++;
		if (!b)
			throw s;
	}

	static function finalReveals(artAt:Float):Int {
		var options = new AutoOptions();
		options.skip.value = true;
		options.loot.value = false;
		var facade = new DBFacade();
		var row:Dynamic = {valid: 1, chest_type_1: 123, chest_type_2: 0, chest_type_3: 0, chest_type_4: 0};
		var holder = new DisplayObjectContainer(0);
		var work = new WorkComponent();
		var summary:Dynamic = {mLeaving: false, mRevealState: 9, mTownHeader: null, mItemCount: 1,
			mDungeonReport: [row, null, null, null], mChestMovieClips: [[holder], [], [], []], mWorkComponent: work};
		var finals = 0, kills = 0, treasureTick = 0;
		var reveal:Dynamic = null;
		function next(state:Int, delay:Float) {
			summary.mRevealState = state;
			work.doLater(delay, reveal);
		}
		reveal = function(clock:Dynamic) {
			switch (summary.mRevealState) {
				case 9: if (++kills >= 5) next(10, 0.45) else next(9, 0.09);
				case 10: next(11, 0.45);
				case 11: if (++treasureTick >= 2) next(12, 0.1) else next(11, 0.45);
				case 12: finals++; summary.mTownHeader = {};
				case _:
			}
		};
		Reflect.setField(summary, "updateRevealState", reveal);
		work.doLater(0.09, reveal);
		var flow = new RewardFlow(new Context(), facade, summary, options);
		var now = 0.0;
		while (now < 8000) {
			now += 5;
			if (now >= artAt)
				holder.numChildren = 1;
			work.mWorkLoopManager.advance(now, {});
			flow.tick(now);
		}
		flow.destroy();
		return finals;
	}

	static function main() {
		check(finalReveals(0) == 1, "artwork already loaded: the last reveal step runs once");
		check(finalReveals(600) == 1, "artwork loaded during the treasure step: the last reveal step runs once");
		check(finalReveals(3000) == 1, "artwork loaded after the guard waited: the last reveal step runs once");
		Sys.println("Fired reveal tasks: " + checks + " checks passed");
	}
}
