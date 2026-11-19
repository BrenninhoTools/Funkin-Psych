package funkin.util;

import openfl.utils.Assets;
import flixel.util.FlxSave;

class CoolUtil
{
	public static inline final DEFAULT_UPDATE_URL:String = "https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt";

	public static function checkForUpdates(url:String = null):String
	{
		var version:String = funkin.ui.mainmenu.MainMenuState.psychEngineVersion.trim();
		if (!Save.data.checkForUpdates) return version;
		if (url == null || url.length == 0) url = DEFAULT_UPDATE_URL;

		var http:haxe.Http = new haxe.Http(url);
		http.onData = function(data:String)
		{
			var online:String = data.split('\n')[0].trim();
			if (online.length > 0) version = online;
		}
		http.onError = function(error) {}
		try
		{
			http.request();
		}
		catch (e:Dynamic) {}
		return version;
	}

	public static inline function quantize(f:Float, snap:Float):Float
		return funkin.util.math.MathUtil.quantize(f, snap);

	public static inline function floorDecimal(value:Float, decimals:Int):Float
		return funkin.util.math.MathUtil.floorDecimal(value, decimals);

	public static inline function numberArray(max:Int, ?min = 0):Array<Int>
		return funkin.util.math.MathUtil.numberArray(max, min);

	public static function capitalize(text:String):String
	{
		if (text == null || text.length == 0) return text;
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();
	}

	public static function titleCase(text:String):String
	{
		if (text == null) return null;
		return [for (word in text.split(' ')) capitalize(word)].join(' ');
	}

	public static function readText(path:String):String
	{
		if (path == null) return null;
		#if sys
		if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getContent(path);
		#end
		if (Assets.exists(path, TEXT)) return Assets.getText(path);
		return null;
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var content:String = readText(path);
		return content != null ? listFromString(content) : [];
	}

	public static function listFromString(string:String, keepEmpty:Bool = true):Array<String>
	{
		if (string == null) return [];
		var result:Array<String> = [];
		for (line in string.replace('\r\n', '\n').replace('\r', '\n').trim().split('\n'))
		{
			var trimmed:String = line.trim();
			if (keepEmpty || trimmed.length > 0) result.push(trimmed);
		}
		return result;
	}

	public static function colorFromString(color:String):FlxColor
	{
		if (color == null) return FlxColor.WHITE;
		var clean:String = ~/[\t\n\r ]/g.replace(color, '');
		if (clean.startsWith('0x') && clean.length > 8) clean = '0x' + clean.substr(clean.length - 8);
		var parsed:Null<FlxColor> = FlxColor.fromString(clean);
		if (parsed == null) parsed = FlxColor.fromString('#$clean');
		return parsed != null ? parsed : FlxColor.WHITE;
	}

	public static function dominantColor(sprite:FlxSprite):Int
	{
		if (sprite == null || sprite.pixels == null) return FlxColor.BLACK;
		var countByColor:Map<Int, Int> = [];
		var pixels = sprite.pixels;
		var startX:Int = sprite.frame != null ? Std.int(sprite.frame.frame.x) : 0;
		var startY:Int = sprite.frame != null ? Std.int(sprite.frame.frame.y) : 0;
		for (col in 0...sprite.frameWidth)
		{
			for (row in 0...sprite.frameHeight)
			{
				var pixel:FlxColor = pixels.getPixel32(startX + col, startY + row);
				if (pixel.alphaFloat <= 0.05) continue;
				var opaque:Int = FlxColor.fromRGB(pixel.red, pixel.green, pixel.blue, 255);
				countByColor.set(opaque, (countByColor.exists(opaque) ? countByColor.get(opaque) : 0) + 1);
			}
		}

		countByColor.remove(FlxColor.BLACK);
		var maxCount:Int = 0;
		var maxKey:Int = FlxColor.BLACK;
		for (key => count in countByColor)
		{
			if (count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static function browserLoad(site:String)
	{
		if (site == null || site.length == 0) return;
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	public static function openFolder(folder:String, absolute:Bool = false)
	{
		#if sys
		if (!absolute) folder = haxe.io.Path.join([Sys.getCwd(), folder]);
		folder = haxe.io.Path.removeTrailingSlashes(folder);
		#if windows
		Sys.command('explorer.exe', [folder.replace('/', '\\')]);
		#elseif mac
		Sys.command('/usr/bin/open', [folder]);
		#elseif linux
		Sys.command('/usr/bin/xdg-open', [folder]);
		#else
		FlxG.log.warn('Opening folders is not supported on this platform');
		#end
		#else
		FlxG.log.warn('Opening folders is not supported on this platform');
		#end
	}

	@:access(flixel.util.FlxSave.validate)
	public static function getSavePath():String
	{
		final company:String = FlxG.stage.application.meta.get('company');
		return '$company/${FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		if (text == null) return;
		text.borderStyle = switch (border != null ? border.toLowerCase().trim() : '')
		{
			case 'shadow': SHADOW;
			case 'outline': OUTLINE;
			case 'outline_fast', 'outlinefast': OUTLINE_FAST;
			default: NONE;
		}
	}
}
