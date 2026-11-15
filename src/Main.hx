package mods.auto_dungeon_loot_manager;

import mods.api.Context;
import mods.api.Mod;
import brain.event.EventComponent;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import facade.DBFacade;
import openfl.events.Event;
import openfl.ui.Keyboard;
import stateMachine.mainStateMachine.LoadingScreenState;
import distributedObjects.PlayerGameObjectOwner;
import distributedObjects.DistributedDungeonSummary;

class Main extends Mod {
    var context:Context;
    var facade:DBFacade;
    var saved:EntrySettings;
    var pendingEntry:EntrySettings;
    var exitHook:ExitHook = new ExitHook();
    var pending:Bool = false;
    var deadline:Float = 0;
    var player:PlayerGameObjectOwner;
    var localHero:distributedObjects.HeroGameObjectOwner;
    var summary:DistributedDungeonSummary;
    var summaryControls:SummaryControls;
    var summaryControlsFailed:Bool = false;
    var summaryExit:Bool = false;
    var exitControls:ExitControls;
    var uiTick:Float = 0;
    var options:AutoOptions;
    var rewards:RewardFlow;
    var countdown:RestartCountdown = new RestartCountdown();
    var nextPrivacy:NextPrivacy = new NextPrivacy();

    override public function init(context:Context):Void {
        this.context = context;
        options = new AutoOptions(context);
        context.core.onObjectReady(function(object) {
            if (Std.isOfType(object,distributedObjects.HeroGameObjectOwner)) localHero=cast object;
            if (Std.isOfType(object, DistributedDungeonSummary)) {
                clearSummary();
                summary = cast object;
                summaryControlsFailed = false;
                countdown.reset();
            }
            if (Std.isOfType(object, PlayerGameObjectOwner)) {
                player = cast object;
                syncGold(player);
            }
        });
        context.core.onFieldReceived(function(object, field, name) {
            if (Std.isOfType(object, PlayerGameObjectOwner) && StringTools.endsWith(name, ".basicCurrency"))
                syncGold(cast object);
        });
        context.core.onObjectGone(function(object) {
            if(object==localHero) localHero=null;
            if (object == summary) clearSummary();
            if (object == player) {
                syncGold(player);
                player = null;
            }
        });
        context.core.onStateEnter(stateEntered);
        context.core.onStateExit(function(machine, state) {
            if (facade == null || machine != facade.mainStateMachine) return;
            // MainStateMachine already wrote the loading arguments, but the loading state's
            // enterState (and its network request) has not run yet at this point.
            if (state.name == "ReloadTownState")
                nextPrivacy.apply(Reflect.field(facade.mainStateMachine, "mLoadingScreenState"));
            if (state.name == "RunState" && pending) cancel("restart cancelled by another state transition");
        });
        context.keys.action("restartDungeon", "Restart dungeon", "Exit and restart the current dungeon.",
            Keyboard.R, true, true, false).onPress(function() { requestRestart(); });
        context.overlay.addEventListener(Event.ENTER_FRAME, update);
    }

    override public function ready(context:Context):Void {
        facade = context.core.facade;
        if (facade.mainStateMachine.currentStateName == "RunState") captureRetainedEntry();
        context.log("loaded: Auto Dungeon / Loot Manager; restart shortcut registered through context.keys");
    }

    function syncGold(owner:PlayerGameObjectOwner):Void {
        if (owner != null && facade != null && facade.dbAccountInfo != null)
            GoldCache.sync(facade.dbAccountInfo, owner.basicCurrency);
    }

    function stateEntered(machine:StateMachine, state:State):Void {
        if (facade == null || machine != facade.mainStateMachine) return;
        if (Std.isOfType(state, LoadingScreenState)) {
            var entry = new EntrySettings(state);
            saved = entry.valid() ? entry : null;
        }
        if (state.name == "TownState" || state.name == "SocketErrorState") nextPrivacy.clear();
    }

    function captureRetainedEntry():Void {
        var state = Reflect.field(facade.mainStateMachine, "mLoadingScreenState");
        if (state == null) return;
        var entry = new EntrySettings(state);
        if (entry.valid()) saved = entry;
    }

    function requestRestart(manual:Bool = true):Bool {
        if (manual) cancelAuto();
        if (pending) return true;
        if (facade == null || !context.core.alive
            || facade.mainStateMachine.currentStateName != "RunState") return false;
        if (saved == null) captureRetainedEntry();
        if (saved == null || !saved.valid()) {
            context.log("restart unavailable: no valid dungeon entry settings");
            return true;
        }
        // Resolve friend/instance entries to the current dungeon's node so replay
        // uses normal matchmaking instead of explicitly joining the old instance.
        if (facade.dbAccountInfo != null && facade.dbAccountInfo.activeAvatarInfo != null) {
            var hero:Dynamic = facade.gameObjectManager.getReferenceFromId(facade.dbAccountInfo.activeAvatarInfo.id);
            var floor:Dynamic = hero == null ? null : Reflect.field(hero, "distributedDungeonFloor");
            var node:Dynamic = floor == null ? null : Reflect.field(floor, "mMapNode");
            if (node != null) {
                saved.mapNodeID = node.Id;
                saved.nodeType = node.NodeType;
            }
        }
        if (summary != null) {
            var section = Reflect.field(summary, "mNextFloorSection");
            var current:Dynamic = section == null ? null : Reflect.field(section, "mCurrentDungeon");
            if (current != null) {
                saved.mapNodeID = current.Id;
                saved.nodeType = current.NodeType;
            }
        }
        if (saved.mapNodeID == 0) {
            context.log("restart unavailable: current dungeon node could not be resolved");
            return true;
        }
        saved.friendID = 0;
        saved.mapID = 0;
        saved.jumpToMap = false;
        var summaryCallback:Dynamic = null;
        if (summary != null) {
            var reason = SummaryRules.blocked(summary);
            if (reason != null) {
                context.log("restart unavailable: " + reason);
                return true;
            }
            var section = Reflect.field(summary, "mNextFloorSection");
            summaryCallback = section == null ? null : Reflect.field(section, "mCallback");
            if (!Reflect.isFunction(summaryCallback)) {
                context.log("restart unavailable: native summary exit callback was not found");
                return true;
            }
        }
        if (facade.mDistributedObjectManager == null || facade.mDistributedObjectManager.mMatchMaker == null) return true;
        var run = Reflect.field(facade.mainStateMachine, "mRunState");
        var events:EventComponent = cast Reflect.field(run, "mEventComponent");
        try {
            if (!exitHook.arm(events, exited)) {
                context.log("restart unavailable: normal dungeon exit handler was not found");
                return true;
            }
            pendingEntry = saved;
            summaryExit = summary != null;
            syncGold(player);
            pending = true;
            deadline = Date.now().getTime() + 15000;
            context.log("restart requested; waiting for server exit confirmation");
            if (summaryExit) {
                // Native summary cleanup, without invoking Next's different-dungeon callback.
                Reflect.callMethod(summary, summaryCallback, []);
            } else {
                // Close the confirmation popup before leaving; its own destroy
                // method also clears the HUD's retained popup reference.
                var popup = ExitControls.find(facade);
                if (popup != null) Reflect.callMethod(popup, Reflect.field(popup, "destroy"), []);
                facade.dbAccountInfo.dbAccountParams.flushParams();
                facade.mDistributedObjectManager.mMatchMaker.RequestExit();
            }
        } catch (error:Dynamic) {
            cancel("restart request failed: " + Std.string(error));
        }
        return true;
    }

    function exitTitle():String {
        var floor = localHero == null ? null : localHero.distributedDungeonFloor;
        if (floor == null || floor.gmMapNode == null) return "";
        var name = floor.gmMapNode.Name;
        if (name == null || StringTools.trim(name) == "") return "";
        var current = floor.getCurrentFloorNum();
        var maximum = floor.getMaxFloorNum();
        return name + " - Floor " + current + " / " + (maximum > 0 ? Std.string(maximum) : "?");
    }

    function exited(event:Event):Void {
        if (!pending) return;
        var entry = pendingEntry;
        var refreshAccount = summaryExit;
        pending = false;
        pendingEntry = null;
        summaryExit = false;
        exitHook.restore();
        try {
            if (entry == null || !entry.valid()) throw "saved entry is unavailable";
            if (refreshAccount) {
                context.log("summary exit confirmed; refreshing rewards before re-entering dungeon");
                var machine = facade.mainStateMachine;
                machine.setOneShotReloadTownCallback(function() {
                    if (!context.core.alive) { machine.enterTownState(); return; }
                    reenter(entry);
                });
                machine.enterReloadTownState();
            } else {
                context.log("exit confirmed; re-entering dungeon");
                reenter(entry);
            }
        } catch (error:Dynamic) {
            context.log("restart failed; returning to town: " + Std.string(error));
            facade.mainStateMachine.enterReloadTownState();
        }
    }

    function update(event:Event):Void {
        if (pending && Date.now().getTime() > deadline) cancel("restart timed out; normal exit behavior restored");
        if (facade == null || !context.core.alive) return;
        var now = Date.now().getTime();
        if (now < uiTick) return;
        uiTick = now + 100;
        try { options.refreshMenu(facade); }
        catch (error:Dynamic) { context.log("settings layout: " + Std.string(error)); }
        var popup = ExitControls.find(facade);
        if (exitControls != null && !exitControls.matches(popup)) {
            exitControls.destroy();
            exitControls = null;
        }
        if (popup != null && exitControls == null) {
            try { exitControls = new ExitControls(facade, popup, function() { requestRestart(); }, exitTitle()); }
            catch (error:Dynamic) { context.log("exit button unavailable: " + Std.string(error)); }
        }
        if (exitControls != null) exitControls.update(!pending && saved != null && saved.valid());
        if (summary == null || summaryControlsFailed) return;
        try {
            if (rewards == null) rewards = new RewardFlow(context, facade, summary, options);
            rewards.tick(now);
            if (summaryControls == null) summaryControls = new SummaryControls(facade, summary, options,
                function() { requestRestart(); }, function() { cancelAuto(); rememberNextPrivacy(); }, cancelAuto);
            summaryControls.update(!pending && saved != null && saved.valid() && SummaryRules.blocked(summary) == null);
            var activeLayer = facade.menuNavigationController.getTopUILayer();
            var settled = activeLayer == "DISTRIBUTED_DUNGEON_SUMMARY" && !pending && saved != null && saved.valid() && rewards.settled()
                && facade.mainStateMachine.currentStateName == "RunState";
            var fire = countdown.tick(now, options.auto.value, settled, options.delay());
            var left = countdown.remaining(now);
            summaryControls.status(left >= 0 ? (options.swap.value == "yes" ? "Restart in " : "Auto Next in ") + left + "s"
                : (options.auto.value && rewards.paused && !countdown.cancelled ? "Auto Next / Restart paused" : ""));
            if (fire) {
                if (options.swap.value == "yes") requestRestart(false);
                else if (!summaryControls.autoNext()) {
                    countdown.cancel();
                    context.log("automatic Next skipped: native button is unavailable");
                }
            }
        } catch (error:Dynamic) {
            summaryControlsFailed = true;
            context.log("summary button unavailable: " + Std.string(error));
            if (summaryControls != null) summaryControls.destroy();
            summaryControls = null;
        }
    }

    function reenter(entry:EntrySettings):Void {
        facade.mainStateMachine.enterLoadingScreenState(entry.mapNodeID, entry.nodeType,
            entry.friendID, entry.mapID, entry.jumpToMap, entry.friendsOnly);
    }

    function rememberNextPrivacy():Void {
        if (saved == null) captureRetainedEntry();
        if (summary == null || saved == null || !saved.valid()) return;
        var section = Reflect.field(summary, "mNextFloorSection");
        var next = section == null ? null : Reflect.field(section, "mNextDungeon");
        if (next != null) nextPrivacy.arm(next.Id, saved.friendsOnly);
    }

    function cancelAuto():Void {
        countdown.cancel();
        if (summaryControls != null) summaryControls.status("");
    }

    function clearSummary():Void {
        countdown.cancel();
        if (rewards != null) rewards.destroy();
        rewards = null;
        if (summaryControls != null) summaryControls.destroy();
        summaryControls = null;
        summary = null;
    }

    function cancel(reason:String):Void {
        pending = false;
        pendingEntry = null;
        summaryExit = false;
        exitHook.restore();
        if (context != null) context.log(reason);
    }

    override public function dispose():Void {
        pending = false;
        pendingEntry = null;
        summaryExit = false;
        nextPrivacy.clear();
        if (exitControls != null) exitControls.destroy();
        exitControls = null;
        clearSummary();
        exitHook.restore();
        context.overlay.removeEventListener(Event.ENTER_FRAME, update);
        localHero=null;
        facade = null;
        player = null;
    }
}
