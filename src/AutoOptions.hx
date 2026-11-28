package mods.auto_dungeon_loot_manager;

import mods.api.Context;
import mods.api.settings.Flag;
import mods.api.settings.Choice;

/** The API persists each change; Choice supplies the game's native arrow buttons. */
class AutoOptions {
	public var auto:Flag;
	public var skip:Flag;
	public var loot:Flag;
	public var seconds:Choice;
	public var swap:Choice;

	var common:Flag;
	var uncommon:Flag;
	var rare:Flag;
	var legendary:Flag;
	var small:Flag;
	var royal:Flag;

	public function new(ctx:Context) {
		auto = ctx.settings.flag("autoRestart", "Auto Next / Restart", "Continue or restart after handling loot.", false);
		var choices:Array<Dynamic> = [];
		for (i in 0...11)
			choices.push({value: Std.string(i), label: Std.string(i) + "s"});
		seconds = ctx.settings.choice("restartDelay", "Next / Restart after X seconds", "Delay before continuing or restarting.", choices, "6");
		swap = ctx.settings.choice("swapButtons", "Default Next button", "Choose the main button on the results screen.",
			[{value: "no", label: "Next"}, {value: "yes", label: "Restart"}], "no");
		skip = ctx.settings.flag("skipAnimations", "Skip loot and results animations", "Skips loot reveals, result counts and Sweet popups.", true);
		loot = ctx.settings.flag("autoLoot", "Automatically handle loot", "Choose which chests to keep automatically.", true);
		common = ctx.settings.flag("keepCommon", "Keep common chests", "Keep common chests. Turn off to discard.", true);
		uncommon = ctx.settings.flag("keepUncommon", "Keep uncommon chests", "Keep uncommon chests. Turn off to discard.", true);
		rare = ctx.settings.flag("keepRare", "Keep rare chests", "Keep rare chests. Turn off to discard.", true);
		legendary = ctx.settings.flag("keepLegendary", "Keep legendary chests", "Keep legendary chests. Turn off to discard.", true);
		small = ctx.settings.flag("keepSmallBox", "Keep small item boxes", "Keep small boxes. Turn off to discard.", true);
		royal = ctx.settings.flag("keepRoyalBox", "Keep royal item boxes", "Keep royal boxes. Turn off to discard.", true);
	}

	public function delay():Int {
		var n = Std.parseInt(seconds.value);
		return n == null ? 6 : n;
	}

	public function keep(rarity:String):Bool {
		return switch (rarity) {
			case "COMMON": common.value;
			case "UNCOMMON": uncommon.value;
			case "RARE": rare.value;
			case "LEGENDARY": legendary.value;
			case "CONSUMABLE_SMALL": small.value;
			case "CONSUMABLE_ROYAL": royal.value;
			default: true; // Unknown rewards are always kept.
		};
	}
}
