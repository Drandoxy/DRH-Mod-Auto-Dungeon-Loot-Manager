import mods.auto_dungeon_loot_manager.LevelUpSkipper;
import facade.DBFacade;
import brain.uI.UIButton;
class LevelUpTest {
 static function check(ok:Bool,message:String) {if(!ok)throw message;}
 static function main() {
  var f=new DBFacade();var layer="DUNGEON_SUMMARY_LEVEL_UP_POPUP";var calls=0;
  var close=new UIButton("close_button");var sweet=new UIButton("share");close.downNavigation=sweet;sweet.upNavigation=close;
  sweet.releaseCallback=function(){calls++;};
  f.menuNavigationController={getTopUILayer:function()return layer,focusedUiObject:close};
  var skipper=new LevelUpSkipper();skipper.tick(f,false);check(calls==0,"Setting off dismissed popup");
  skipper.tick(f,true);skipper.tick(f,true);check(calls==1,"Did not invoke Sweet exactly once");
  layer="PURCHASE_POPUP";skipper.tick(f,true);check(calls==1,"Unrelated popup dismissed");
  layer="DUNGEON_SUMMARY_LEVEL_UP_POPUP";sweet.enabled=false;skipper.tick(f,true);check(calls==1,"Disabled button pressed");
  sweet.enabled=true;sweet.root.stage=null;skipper.tick(f,true);check(calls==1,"Unloaded button pressed");
  sweet.root.stage={};skipper.tick(f,true);check(calls==2,"Next popup did not rearm");
  skipper.destroy();
  var defaults=new Map<String,Dynamic>();defaults.set("DUNGEON_SUMMARY_LEVEL_UP_POPUP",close);
  Reflect.setField(f.menuNavigationController,"mDefaultUIObjs",defaults);
  Reflect.setField(f.menuNavigationController,"focusedUiObject",null);
  skipper.tick(f,false);check(calls==2,"No-focus setting off dismissed popup");
  skipper.tick(f,true);skipper.tick(f,true);check(calls==3,"No-focus Sweet popup was not acknowledged exactly once");
  trace("PASS: skip setting off/on, exact popup, native Sweet callback, once-only, disabled/unloaded guards, rearm");
 }
}
