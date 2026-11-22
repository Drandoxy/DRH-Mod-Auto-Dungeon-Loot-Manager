import mods.api.Context;
import mods.auto_dungeon_loot_manager.PartyTimeGuard;
import mods.party_auto_join.Main;
class PartyIntegrationTest {
 static function main() {
  var ctx=new Context();var guard=new PartyTimeGuard(ctx);
  var root=new openfl.display.DisplayObjectContainer();var managerLayer=new openfl.display.DisplayObjectContainer();var partyLayer=new openfl.display.DisplayObjectContainer();root.children=[managerLayer,partyLayer];root.numChildren=2;managerLayer.parent=root;partyLayer.parent=root;var marker:Dynamic={name:"party_auto_join_progression_hold",alpha:1.};partyLayer.children=[marker];ctx.core.overlay=managerLayer;
  if(guard.active(0)||guard.autoHeld(0))throw "inactive integration blocks progression";
  ctx.activeMods=["party_auto_join"];
  if(!guard.active(0)||!guard.autoHeld(0))throw "shared state unavailable";
  marker.alpha=.5;
  if(guard.active(1)||!guard.autoHeld(1))throw "independent hold lost";
  marker.alpha=0.;
  if(guard.active(2)||guard.autoHeld(2))throw "manual state did not release";
  ctx.activeMods=[];marker.alpha=1.;
  if(guard.active(3))throw "failed/disposed mod retained hold";
  trace("PASS: optional-mod presence and independent shared-state flags without file I/O");
 }
}
