import mods.auto_dungeon_loot_manager.LevelUpDismissal;
class LevelUpDismissalTest {
 static function check(ok:Bool,msg:String) {if(!ok)throw msg;}
 static function main() {
  var layer="DUNGEON_SUMMARY_LEVEL_UP_POPUP";
  var callbacks=new Map<String,Dynamic>();var count=0;
  callbacks.set(layer,function(){count++;});
  var nav:Dynamic={getTopUILayer:function()return layer,mLayerExitCallbacks:callbacks,focusedUiObject:null};
  var skip=new LevelUpDismissal();
  skip.tick(nav,false);check(count==0,"Setting off");
  skip.tick(nav,true);skip.tick(nav,true);check(count==1,"No-focus once-only close");
  callbacks.set(layer,function(){count+=2;});skip.tick(nav,true);check(count==3,"New popup without intervening tick");
  layer="PURCHASE_POPUP";skip.tick(nav,true);check(count==3,"Other dialog");
  layer="DUNGEON_SUMMARY_LEVEL_UP_POPUP";skip.tick(nav,true);check(count==5,"Rearm");
  skip.clear();callbacks.remove(layer);check(!skip.tick(nav,true),"Missing callback");
  trace("PASS: setting off, no focus, exact layer, once per callback, successive popups and missing callback");
 }
}
