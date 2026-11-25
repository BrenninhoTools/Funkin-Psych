package funkin.graphics;

import funkin.assets.AssetCache;
#if GIF_ALLOWED
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import gifsupport.Gif;
import gifsupport.GifSpriteSheet;
import gifsupport.openfl.GifBitmap;
import haxe.io.Bytes;
import openfl.display.BitmapData;
#end

typedef GifSheetData =
{
	var xml:String;
	var frameCount:Int;
	var frameRate:Float;
	var looped:Bool;
	var scale:Float;
	var delays:Array<Int>;
}

class GifLoader
{
	public static inline final EXTENSION:String = 'gif';
	public static inline final PREFIX:String = 'gif';
	public static var maxSheetSize:Int = #if mobile 4096 #else 8192 #end;

	static var sheets:Map<String, GifSheetData> = new Map();

	public static var available(get, never):Bool;

	public static function exists(key:String, ?parentFolder:String):Bool
	{
		#if GIF_ALLOWED
		return key != null && key.length > 0 && Paths.fileExists('images/$key.$EXTENSION', BINARY, false, parentFolder);
		#else
		return false;
		#end
	}

	public static function onlyGif(key:String, ?parentFolder:String):Bool
	{
		return exists(key, parentFolder) && !Paths.fileExists('images/$key.${Paths.IMAGE_EXT}', IMAGE, false, parentFolder);
	}

	#if GIF_ALLOWED
	public static function bytes(key:String, ?parentFolder:String):Bytes
	{
		var path:String = Paths.getPath('images/$key.$EXTENSION', BINARY, parentFolder, true);
		return Paths.getBytes(path);
	}

	public static function load(key:String, ?parentFolder:String, ?maxFrames:Int):Gif
	{
		var data:Bytes = bytes(key, parentFolder);
		if (data == null) return null;
		try
		{
			return maxFrames != null && maxFrames > 0 ? Gif.fromBytes(data, maxFrames) : Gif.fromBytes(data);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Could not decode GIF $key: $e');
			return null;
		}
	}
	#end

	public static function firstFrame(key:String, ?parentFolder:String, ?allowGPU:Bool = true):#if GIF_ALLOWED FlxGraphic #else Dynamic #end
	{
		#if GIF_ALLOWED
		var cacheKey:String = 'images/$key.$EXTENSION.first';
		var cached:FlxGraphic = AssetCache.getGraphic(cacheKey);
		if (cached != null) return cached;

		var data:Bytes = bytes(key, parentFolder);
		if (data == null) return null;
		try
		{
			var gif:Gif = Gif.firstFrame(data);
			if (gif == null || gif.frames.length == 0) return null;
			return Paths.cacheBitmap(cacheKey, parentFolder, GifBitmap.toBitmapData(gif, 0), allowGPU);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Could not decode GIF $key: $e');
			return null;
		}
		#else
		return null;
		#end
	}

	public static function frames(key:String, ?parentFolder:String, ?allowGPU:Bool = true):#if GIF_ALLOWED FlxAtlasFrames #else Dynamic #end
	{
		#if GIF_ALLOWED
		var cacheKey:String = 'images/$key.$EXTENSION';
		var graphic:FlxGraphic = AssetCache.getGraphic(cacheKey);
		var data:GifSheetData = sheets.get(cacheKey);

		if (graphic == null || data == null)
		{
			var gif:Gif = load(key, parentFolder);
			if (gif == null || gif.frames.length == 0) return null;

			var scale:Float = fitScale(gif);
			if (scale < 1)
				gif = gif.resize(Std.int(Math.max(1, Math.floor(gif.width * scale))), Std.int(Math.max(1, Math.floor(gif.height * scale))));

			var sheet:GifSpriteSheet = gif.toSpriteSheet(0, 1);
			var bitmap:BitmapData = GifBitmap.spriteSheetToBitmapData(sheet);
			graphic = Paths.cacheBitmap(cacheKey, parentFolder, bitmap, allowGPU);
			if (graphic == null) return null;

			data = {
				xml: sheet.toSparrowXml('$key.$EXTENSION', PREFIX),
				frameCount: gif.frames.length,
				frameRate: gif.averageFrameRate > 0 ? gif.averageFrameRate : 10,
				looped: gif.playCount != 1,
				scale: scale < 1 ? scale : 1,
				delays: [for (frame in gif.frames) frame.delay]
			};
			sheets.set(cacheKey, data);
		}

		return FlxAtlasFrames.fromSparrow(graphic, data.xml);
		#else
		return null;
		#end
	}

	public static function info(key:String):Null<GifSheetData>
	{
		return sheets.get('images/$key.$EXTENSION');
	}

	public static function apply(sprite:FlxSprite, key:String, animationName:String = 'gif', ?frameRate:Float, ?looped:Bool, autoPlay:Bool = true,
			?parentFolder:String):Bool
	{
		#if GIF_ALLOWED
		var atlas:FlxAtlasFrames = frames(key, parentFolder);
		if (atlas == null) return false;
		var data:GifSheetData = info(key);
		sprite.frames = atlas;
		sprite.animation.addByPrefix(animationName, PREFIX, frameRate != null && frameRate > 0 ? frameRate : data.frameRate,
			looped != null ? looped : data.looped);
		if (data.scale < 1)
		{
			sprite.scale.set(sprite.scale.x / data.scale, sprite.scale.y / data.scale);
			sprite.updateHitbox();
		}
		if (autoPlay) sprite.animation.play(animationName, true);
		return true;
		#else
		return false;
		#end
	}

	public static function isGifFrames(sprite:FlxSprite):Bool
	{
		return sprite != null && sprite.frames != null && sprite.frames.frames.length > 0 && sprite.frames.frames[0].name != null
			&& StringTools.startsWith(sprite.frames.frames[0].name, PREFIX) && sprite.frames.parent != null && sprite.frames.parent.key != null
			&& StringTools.endsWith(sprite.frames.parent.key, '.$EXTENSION');
	}

	public static function clearCache():Void
	{
		for (key in sheets.keys())
			if (AssetCache.getGraphic(key) == null) sheets.remove(key);
	}

	#if GIF_ALLOWED
	static function fitScale(gif:Gif):Float
	{
		var cell:Float = (gif.width + 1) * (gif.height + 1);
		var area:Float = cell * gif.frames.length;
		var limit:Float = maxSheetSize * maxSheetSize * 0.9;
		var scale:Float = area > limit ? Math.sqrt(limit / area) : 1;
		var side:Float = Math.max(gif.width, gif.height) * scale;
		if (side > maxSheetSize) scale *= maxSheetSize / side;
		return scale;
	}
	#end

	static function get_available():Bool
	{
		#if GIF_ALLOWED
		return true;
		#else
		return false;
		#end
	}
}
