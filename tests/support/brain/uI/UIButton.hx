package brain.uI;
class UIButton extends UIObject {
 public var enabled:Bool=true; public var releaseCallback:Void->Void;
 public function new(name:String) {super();root={name:name,visible:true,stage:{}};}
}
