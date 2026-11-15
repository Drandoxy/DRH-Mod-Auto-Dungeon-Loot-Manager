package mods.auto_dungeon_loot_manager;

import mods.api.Context;
import mods.api.settings.Flag;
import mods.api.settings.Choice;
import facade.DBFacade;
import stateMachine.mainStateMachine.TownState;
import settings.view.SettingsList;

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
    var dirty:Bool = true;
    var delayCategory:String;
    var visible:Null<Bool> = null;

    public function new(ctx:Context) {
        auto = ctx.settings.flag("autoRestart", "Auto Next / Restart", "Continue or restart after handling loot.", false);
        var choices:Array<Dynamic> = [];
        for (i in 0...11) choices.push({value: Std.string(i), label: Std.string(i) + "s"});
        seconds = ctx.settings.choice("restartDelay", "Next / Restart after X seconds", "Delay before continuing or restarting.", choices, "6");
        swap = ctx.settings.choice("swapButtons", "Default Next button", "Choose the main button on the results screen.", [{value: "no", label: "Next"}, {value: "yes", label: "Restart"}], "no");
        skip = ctx.settings.flag("skipAnimations", "Skip loot and results animations", "Skip loot reveals and results counting.", true);
        loot = ctx.settings.flag("autoLoot", "Automatically handle loot", "Choose which chests to keep automatically.", true);
        common = ctx.settings.flag("keepCommon", "Keep common chests", "Keep common chests. Turn off to discard.", true);
        uncommon = ctx.settings.flag("keepUncommon", "Keep uncommon chests", "Keep uncommon chests. Turn off to discard.", true);
        rare = ctx.settings.flag("keepRare", "Keep rare chests", "Keep rare chests. Turn off to discard.", true);
        legendary = ctx.settings.flag("keepLegendary", "Keep legendary chests", "Keep legendary chests. Turn off to discard.", true);
        small = ctx.settings.flag("keepSmallBox", "Keep small item boxes", "Keep small boxes. Turn off to discard.", true);
        royal = ctx.settings.flag("keepRoyalBox", "Keep royal item boxes", "Keep royal boxes. Turn off to discard.", true);
        auto.onChange(function(value) { dirty = true; });
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
    public function refreshMenu(facade:DBFacade):Void {
        if (facade == null) return;
        var entry:Dynamic = Reflect.field(seconds, "entry");
        var definition:Dynamic = entry == null ? null : Reflect.field(entry, "definition");
        if (definition == null) return;
        if (delayCategory == null) delayCategory = definition.category;
        var shown = auto.value;
        definition.category = shown ? delayCategory : "auto_dungeon_loot_manager_hidden";
        // Rebuild only the currently shown mod category, after its change callback.
        var popup:Dynamic = facade.hud == null ? null : Reflect.field(facade.hud, "mSettingsPopup");
        if (popup == null) {
            var town:TownState = Std.downcast(facade.mainStateMachine.currentState, TownState);
            var machine = town == null ? null : town.townStateMachine;
            var home:Dynamic = machine == null ? null : Reflect.field(machine, "mHomeState");
            popup = home == null ? null : Reflect.field(home, "mSettingsPopup");
        }
        var list:SettingsList = popup == null ? null : cast Reflect.field(popup, "mList");
        if (list == null) return;
        var rows = list.rows;
        var ours = false;
        if (rows != null) for (i in 0...rows.length) {
            var row:Dynamic = rows[i];
            var def:Dynamic = row.definition;
            if (def != null && def.id == "mods.auto_dungeon_loot_manager.autoRestart") ours = true;
        }
        if (!ours) return;
        var hasDelay = false;
        for (i in 0...rows.length)
            if (rows[i].definition.id == "mods.auto_dungeon_loot_manager.restartDelay") hasDelay = true;
        if (hasDelay == shown) { dirty = false; visible = shown; return; }
        list.showCategory(delayCategory);
        Reflect.callMethod(popup, Reflect.field(popup, "rebuildNavigation"), []);
        rows = list.rows;
        if (rows != null) for (i in 0...rows.length) {
            var row:Dynamic = rows[i];
            var def:Dynamic = row.definition;
            if (def != null && def.id == "mods.auto_dungeon_loot_manager.autoRestart") {
                facade.menuNavigationController.setFocusedUiObject(cast row);
                list.scrollRowIntoView(row);
                break;
            }
        }
        dirty = false;
        visible = shown;
    }
}
