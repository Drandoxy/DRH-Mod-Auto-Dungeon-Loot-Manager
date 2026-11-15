package mods.auto_dungeon_loot_manager;
class AutoOptions {
    public var skip:Dynamic = {value:false};
    public var loot:Dynamic = {value:true};
    public var keepValue:Bool = true;
    public function new() {}
    public function keep(rarity:String):Bool {return keepValue;}
}
