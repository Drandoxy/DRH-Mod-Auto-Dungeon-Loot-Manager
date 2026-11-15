import mods.auto_dungeon_loot_manager.RewardFlow;
import mods.auto_dungeon_loot_manager.AutoOptions;
import mods.api.Context;
import facade.DBFacade;
import brain.workLoop.WorkComponent;
import openfl.display.DisplayObjectContainer;
class RewardFlowTest {
    static var checks=0;
    static function check(b:Bool,s:String) {checks++;if(!b)throw s;}
    static function main() {
        var ctx=new Context(); var facade=new DBFacade(); var options=new AutoOptions();
        var keeps=0; var drops=0; var room=true;
        facade.gameMaster={dooberById:new Lookup({ChestId:60003}),chestsById:new Lookup({Id:60003,Rarity:"RARE"})};
        facade.dbAccountInfo={id:1,inventoryInfo:{hasRoomForChest:function(id:Int) return room}};
        var row:Dynamic={valid:1,chest_type_1:123,chest_type_2:0,chest_type_3:0,chest_type_4:0};
        var holder=new DisplayObjectContainer(1); var work=new WorkComponent();
        var summary:Dynamic={mLeaving:false,mRevealState:12,mTownHeader:{},mItemCount:1,
            mDungeonReport:[row,null,null,null],mChestMovieClips:[[holder],[],[],[]],mWorkComponent:work};
        Reflect.setField(summary,"keepChestFromInventory",function(slot:Int,from:Bool) {keeps++;Reflect.setField(summary,"mInfoPopup",{});});
        Reflect.setField(summary,"closeKeyChestPopup",function() {Reflect.setField(summary,"mTreasureFoundPopup",null);});
        Reflect.setField(summary,"loadNextChestPopUp",function() {});
        Reflect.setField(summary,"removeItemFromSlot",function(slot:Int) {row.chest_type_1=0;summary.mItemCount=0;});
        Reflect.setField(summary,"mNetworkComponent",{send_DropChest:function(id:Int,slot:Int) {drops++;}});
        var flow=new RewardFlow(ctx,facade,summary,options);
        flow.tick(0); flow.tick(100);flow.tick(500);
        check(keeps==1,"keep request sent only once while confirmation pending");
        check(!flow.settled(),"unconfirmed keep blocks restart");
        row.chest_type_1=0;summary.mItemCount=0;
        check(!flow.settled(),"account refresh still blocks restart");
        summary.mInfoPopup=null;flow.tick(700);
        check(flow.settled(),"server-confirmed keep permits countdown");
        check(drops==0,"keeping never discards");
        flow.destroy();
        row.chest_type_1=123;summary.mItemCount=1;
        flow=new RewardFlow(ctx,facade,summary,options);flow.tick(0);flow.tick(10001);
        check(flow.paused,"keep timeout pauses automation");check(!flow.settled(),"timeout cannot restart");
        check(drops==0,"timeout never falls back to discard");flow.destroy();
        summary.mInfoPopup=null;room=false;
        flow=new RewardFlow(ctx,facade,summary,options);flow.tick(0);
        check(flow.paused,"full storage pauses automation");check(drops==0,"full storage cannot discard");flow.destroy();
        room=true;options.keepValue=false;
        flow=new RewardFlow(ctx,facade,summary,options);flow.tick(0);
        check(drops==1,"explicit discard rule invokes native drop");flow.destroy();
        row.chest_type_1=123;summary.mItemCount=1;holder.numChildren=0;summary.mRevealState=10;
        options.skip.value=true;options.loot.value=false;var revealed=0;
        var reveal=function(clock:Dynamic) {revealed++;summary.mRevealState=12;};
        Reflect.setField(summary,"updateRevealState",reveal);var task=work.doLater(0.1,reveal);
        flow=new RewardFlow(ctx,facade,summary,options);flow.tick(0);
        check(revealed==0,"skip waits for chest artwork");
        var guarded:Dynamic=task.callback;work.mWorkLoopManager.removeDoLater(task);work.mTasks.remove(task);guarded({});
        check(revealed==0,"native timer also waits at the asset barrier");
        holder.numChildren=1;flow.tick(200);
        check(revealed==1,"loaded artwork releases the original reveal callback");
        flow.destroy();
        holder.numChildren=0;summary.mRevealState=10;revealed=0;
        task=work.doLater(0.1,reveal);flow=new RewardFlow(ctx,facade,summary,options);
        flow.tick(0);flow.tick(16000);
        check(flow.paused,"asset timeout pauses auto actions");
        var timeoutCallback:Dynamic=task.callback;work.mWorkLoopManager.removeDoLater(task);work.mTasks.remove(task);timeoutCallback({});
        check(revealed==1,"asset timeout releases native results flow for manual handling");
        flow.destroy();
        options.skip.value=false;options.loot.value=false;
        summary.mRevealState=12;summary.mTownHeader={};summary.mItemCount=1;
        row.chest_type_1=123;summary.mTreasureFoundPopup={};
        flow=new RewardFlow(ctx,facade,summary,options);
        var priorKeeps=keeps;var priorDrops=drops;
        flow.tick(20000);
        check(keeps==priorKeeps && drops==priorDrops,"manual loot mode sends no keep or discard");
        check(summary.mTreasureFoundPopup!=null,"manual loot prompt remains open");
        check(!flow.settled(),"unhandled manual loot blocks countdown");
        row.chest_type_1=0;summary.mItemCount=0;
        check(!flow.settled(),"last manual loot popup must close before countdown");
        summary.mTreasureFoundPopup=null;
        check(flow.settled(),"manual loot complete and dialogs closed permits countdown");
        flow.destroy();
        Sys.println("Reward flow: "+checks+" checks passed");
    }
}
class Lookup {var item:Dynamic;public function new(item:Dynamic){this.item=item;}public function itemFor(id:Int):Dynamic{return item;}}
