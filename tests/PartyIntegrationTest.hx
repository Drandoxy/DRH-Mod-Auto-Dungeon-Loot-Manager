import mods.api.Context;
import mods.auto_dungeon_loot_manager.PartyTimeGuard;
import mods.party_auto_join.Main;
class PartyIntegrationTest {
 static function main() {
  var ctx=new Context();var guard=new PartyTimeGuard(ctx);
  Main.integrationWaiting=true;Main.integrationHeld=true;
  if(guard.active(0)||guard.autoHeld(0))throw "inactive integration blocks progression";
  ctx.activeMods=["party_auto_join"];
  if(!guard.active(0)||!guard.autoHeld(0))throw "shared state unavailable";
  Main.integrationWaiting=false;
  if(guard.active(1)||!guard.autoHeld(1))throw "independent hold lost";
  Main.integrationHeld=false;
  if(guard.active(2)||guard.autoHeld(2))throw "manual state did not release";
  ctx.activeMods=[];Main.integrationWaiting=true;
  if(guard.active(3))throw "failed/disposed mod retained hold";
  trace("PASS: optional-mod presence and independent shared-state flags without file I/O");
 }
}
