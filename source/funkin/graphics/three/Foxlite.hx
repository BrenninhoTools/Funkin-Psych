package funkin.graphics.three;

#if foxlite
import foxlite.loaders.FoxLoaderUtil;
import openfl.utils.AssetType;

class Foxlite
{
	public static var ready(default, null):Bool = false;

	public static function init():Void
	{
		if (ready) return;
		ready = true;
		#if sys
		lime.utils.Assets.registerLibrary(ModAssetLibrary.NAME, new ModAssetLibrary());
		#end
		FoxLoaderUtil.filePath = (name:String) -> resolve(name);
		FoxLoaderUtil.imagePath = (name:String) -> resolve('images/$name.png', IMAGE);
		FoxLoaderUtil.jsonPath = (name:String) -> resolve('data/$name.json');
	}

	public static function resolve(file:String, ?type:AssetType):String
	{
		if (file == null) return null;
		if (file.indexOf(':') > 1) return file;
		#if MODS_ALLOWED
		var modded:String = Paths.modFolders(file);
		if (sys.FileSystem.exists(modded)) return '${ModAssetLibrary.NAME}:$modded';
		#end
		#if sys
		if (sys.FileSystem.exists(file)) return '${ModAssetLibrary.NAME}:$file';
		#end
		return Paths.getPath(file, type != null ? type : BINARY, null, false);
	}
}
#end
