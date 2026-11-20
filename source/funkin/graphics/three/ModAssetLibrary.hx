package funkin.graphics.three;

#if (sys && foxlite)
import lime.graphics.Image;
import lime.utils.AssetLibrary;
import lime.utils.Bytes;

class ModAssetLibrary extends AssetLibrary
{
	public static inline final NAME:String = 'funkinfs';

	public function new()
	{
		super();
	}

	override public function exists(id:String, type:String):Bool
		return id != null && sys.FileSystem.exists(id);

	override public function isLocal(id:String, type:String):Bool
		return true;

	override public function getPath(id:String):String
		return id;

	override public function getBytes(id:String):Bytes
		return exists(id, null) ? Bytes.fromFile(id) : null;

	override public function getText(id:String):String
		return exists(id, null) ? sys.io.File.getContent(id) : null;

	override public function getImage(id:String):Image
		return exists(id, null) ? Image.fromFile(id) : null;
}
#end
