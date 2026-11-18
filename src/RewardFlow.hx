package mods.auto_dungeon_loot_manager;

import mods.api.Context;
import mods.api.Dictionaries;
import brain.workLoop.DoLater;
import brain.workLoop.WorkComponent;
import brain.workLoop.WorkLoopManager;
import facade.DBFacade;
import openfl.display.DisplayObjectContainer;

/** Native reveal and chest transactions, sequenced before auto restart. */
class RewardFlow {
	var ctx:Context;
	var facade:DBFacade;
	var summary:Dynamic;
	var options:AutoOptions;
	var fullInventory:Bool;
	var reveal:Dynamic;
	var guard:Dynamic;
	var revealFailed:Bool = false;
	var recoverLoot:Bool = false;
	var waitingSince:Float = -1;
	var waitingSlot:Int = -1;
	var cooldown:Float = 0;
	var artworkWait:Float = -1;

	public var paused(default, null):Bool = false;
	public var pauseReason(default, null):String = "";

	public function new(ctx:Context, facade:DBFacade, summary:Dynamic, options:AutoOptions, fullInventory:Bool = false) {
		this.ctx = ctx;
		this.facade = facade;
		this.summary = summary;
		this.options = options;
		this.fullInventory = fullInventory;
		reveal = Reflect.field(summary, "updateRevealState");
		guard = function(clock:Dynamic) {
			if (summary == null || summary.mLeaving == true)
				return;
			var work:WorkComponent = cast Reflect.field(summary, "mWorkComponent");
			var phase:Int = summary.mRevealState;
			if (!paused && phase >= 10 && phase <= 12 && !artReady()) {
				if (work != null)
					work.doLater(0.1, guard);
				return;
			}
			try {
				Reflect.callMethod(summary, reveal, [clock]);
			} catch (error:Dynamic) {
				if (phase != 12)
					throw error;
				handleFinalRevealFailure(error);
			}
		};
	}

	public function tick(now:Float):Void {
		if (summary == null || summary.mLeaving == true || !ctx.core.alive || (paused && !recoverLoot))
			return;
		if (summary.mChestTransactionFailedPopup != null) {
			pause("chest transaction failed");
			return;
		}
		if (options.loot.value && summary.mStorageFullPopUp != null) {
			pause("storage is full; handle the chest manually");
			return;
		}
		if (options.skip.value && !revealFailed)
			fastForward(now);
		if (!options.loot.value || (paused && !recoverLoot) || summary.mRevealState != 12 || summary.mTownHeader == null)
			return;
		if (!artReady())
			return;
		if (waitingSince >= 0) {
			if (chestAt(waitingSlot) == 0 && summary.mInfoPopup == null) {
				waitingSince = -1;
				waitingSlot = -1;
			} else {
				if (now - waitingSince >= 10000)
					pause("server did not confirm keeping the chest");
				return;
			}
		}
		if (now < cooldown)
			return;
		// Close only the native KEEP/DROP prompt; never close an inventory,
		// storage-full, purchase or transaction-error dialog automatically.
		if (summary.mTreasureFoundPopup != null)
			call("closeKeyChestPopup", []);
		if (SummaryRules.dialogsOpen(summary))
			return;
		if (summary.mItemCount <= 0)
			return;
		var slot = -1;
		for (i in 0...4)
			if (slot < 0 && chestAt(i) != 0)
				slot = i;
		if (slot < 0) {
			pause("reward data is incomplete");
			return;
		}
		var doober:Dynamic = facade.gameMaster.dooberById.itemFor(chestAt(slot));
		var chest:Dynamic = doober == null ? null : facade.gameMaster.chestsById.itemFor(doober.ChestId);
		if (chest == null) {
			pause("chest type is unavailable");
			return;
		}
		if (options.keep(Std.string(chest.Rarity))) {
			if (!fullInventory && !facade.dbAccountInfo.inventoryInfo.hasRoomForChest(chest.Id)) {
				pause("storage is full; handle the chest manually");
				// Restore the game's own chest prompt for manual handling.
				call("loadNextChestPopUp", []);
				return;
			}
			summary.mSelectedItemSlot = slot;
			summary.mSelectedGMChest = chest;
			call("keepChestFromInventory", [slot, true]);
			waitingSince = now;
			waitingSlot = slot;
			cooldown = now + 300;
			ctx.log("keeping summary chest in slot " + slot);
		} else {
			summary.mTookLastItem = false;
			var network:Dynamic = Reflect.field(summary, "mNetworkComponent");
			network.send_DropChest(facade.dbAccountInfo.id, slot);
			call("removeItemFromSlot", [slot]);
			cooldown = now + 350;
			ctx.log("discarded summary chest in slot " + slot + " by the saved rarity rule");
		}
	}

	function fastForward(now:Float):Void {
		try {
			var work:WorkComponent = cast Reflect.field(summary, "mWorkComponent");
			var tasks:Dynamic = work == null ? null : Reflect.field(work, "mTasks");
			var manager:WorkLoopManager = work == null ? null : cast Reflect.field(work, "mWorkLoopManager");
			if (tasks == null || manager == null || !Reflect.isFunction(reveal))
				return;
			// A fixed budget prevents large kill/XP totals stalling a display frame.
			for (step in 0...512) {
				var found:DoLater = null;
				for (key in Dictionaries.keys(tasks)) {
					if (!Std.isOfType(key, DoLater))
						continue;
					var task:DoLater = cast key;
					if (!task.isDestroyed()
						&& task.callback != null
						&& (Reflect.compareMethods(task.callback, reveal) || Reflect.compareMethods(task.callback, guard))) {
						found = task;
						break;
					}
				}
				if (found == null)
					break;
				var phase:Int = summary.mRevealState;
				if (!paused && phase >= 10 && phase <= 12 && !artReady()) {
					// Guard the scheduled callback too, so native time cannot
					// run past the asset barrier while the mod waits.
					found.callback = guard;
					if (artworkWait < 0)
						artworkWait = now;
					if (now - artworkWait > 15000) {
						pause("chest artwork is still loading");
					}
					break;
				}
				// The last native step needs the live summary player and attaches
				// the chest icons. Let its original timer run instead of calling
				// it in the same frame as the accelerated counting steps.
				if (phase == 12) {
					found.callback = guard;
					break;
				}
				manager.removeDoLater(found);
				Dictionaries.remove(tasks, found);
				Reflect.callMethod(summary, reveal, [work.gameClock]);
			}
		} catch (error:Dynamic) {
			revealFailed = true;
			pause("reveal could not finish safely: " + Std.string(error));
		}
	}

	function handleFinalRevealFailure(error:Dynamic):Void {
		revealFailed = true;
		pause("final reward reveal failed: " + Std.string(error));
		// Keep restart paused, but allow normal loot actions once the native
		// treasure UI is available. Never replay the partially completed reveal.
		recoverLoot = true;
		ctx.log("final reveal failed; restart paused, automatic chest collection will continue when ready");
		if (summary.mLeaving == true || summary.mTownHeader == null || summary.mItemCount <= 0 || SummaryRules.dialogsOpen(summary))
			return;
		var hasChest = false;
		for (slot in 0...4)
			if (chestAt(slot) != 0)
				hasChest = true;
		if (!hasChest)
			return;
		try {
			// Replaying the last reveal could create a second header or menu
			// layer. The native loot prompt can open directly from the report.
			call("loadNextChestPopUp", []);
		} catch (promptError:Dynamic) {
			ctx.log("could not open the native loot prompt: " + Std.string(promptError));
		}
	}

	/** Every expected chest must have a loaded icon before the treasure reveal. */
	function artReady():Bool {
		var report:Dynamic = Reflect.field(summary, "mDungeonReport");
		var clips:Dynamic = Reflect.field(summary, "mChestMovieClips");
		if (report == null || clips == null)
			return false;
		for (i in 0...4) {
			var row:Dynamic = report[i];
			if (row == null || row.valid == 0)
				continue;
			var expected = 0;
			for (j in 0...4)
				if (Reflect.field(row, "chest_type_" + (j + 1)) != 0)
					expected++;
			if (expected == 0)
				continue;
			var loaded = 0;
			var list:Dynamic = clips[i];
			if (list != null)
				for (j in 0...list.length) {
					var holder:DisplayObjectContainer = cast list[j];
					if (holder != null && holder.numChildren > 0)
						loaded++;
				}
			if (loaded < expected)
				return false;
		}
		return true;
	}

	function chestAt(slot:Int):Int {
		if (slot < 0 || slot > 3)
			return 0;
		var report:Dynamic = Reflect.field(summary, "mDungeonReport");
		var row:Dynamic = report == null ? null : report[0];
		var value:Dynamic = row == null ? null : Reflect.field(row, "chest_type_" + (slot + 1));
		return value == null ? 0 : Std.int(value);
	}

	function call(name:String, args:Array<Dynamic>):Void {
		var method = Reflect.field(summary, name);
		if (!Reflect.isFunction(method))
			throw "Missing native summary action: " + name;
		Reflect.callMethod(summary, method, args);
	}

	function pause(reason:String):Void {
		recoverLoot = false;
		if (paused)
			return;
		paused = true;
		pauseReason = reason;
		ctx.log("auto restart paused: " + reason);
	}

	public function settled():Bool {
		if (paused || waitingSince >= 0 || SummaryRules.blocked(summary) != null)
			return false;
		for (i in 0...4)
			if (chestAt(i) != 0)
				return false;
		return true;
	}

	public function destroy():Void {
		// A callback already scheduled by the native work component must keep
		// its original action if this mod is disposed before the summary.
		if (summary != null) {
			var work:Dynamic = Reflect.field(summary, "mWorkComponent");
			var tasks:Dynamic = work == null ? null : Reflect.field(work, "mTasks");
			if (tasks != null)
				for (key in Dictionaries.keys(tasks)) {
					var task:DoLater = Std.downcast(key, DoLater);
					if (task != null && !task.isDestroyed() && Reflect.compareMethods(task.callback, guard))
						task.callback = reveal;
				}
		}
		summary = null;
		facade = null;
		ctx = null;
		options = null;
	}
}
