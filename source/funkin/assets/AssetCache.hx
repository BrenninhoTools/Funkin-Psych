package funkin.assets;

import flixel.graphics.FlxGraphic;
import openfl.media.Sound;
import openfl.system.System;
import lime.utils.Assets as LimeAssets;

@:access(openfl.display.BitmapData)
class AssetCache
{
	public static var graphics:Map<String, FlxGraphic> = [];
	public static var sounds:Map<String, Sound> = [];
	public static var localKeys:Array<String> = [];
	public static var exclusions:Array<String> = ['assets/preload/music/freakyMenu.${Paths.SOUND_EXT}'];

	public static function exclude(key:String)
	{
		if (!exclusions.contains(key)) exclusions.push(key);
	}

	public static inline function markUsed(key:String)
	{
		if (!localKeys.contains(key)) localKeys.push(key);
	}

	public static function getGraphic(key:String):FlxGraphic
	{
		var graphic:FlxGraphic = graphics.get(key);
		if (graphic != null) markUsed(key);
		return graphic;
	}

	public static function addGraphic(key:String, graphic:FlxGraphic):FlxGraphic
	{
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		graphics.set(key, graphic);
		markUsed(key);
		return graphic;
	}

	public static function getSound(key:String):Sound
	{
		var sound:Sound = sounds.get(key);
		if (sound != null) markUsed(key);
		return sound;
	}

	public static function addSound(key:String, sound:Sound):Sound
	{
		sounds.set(key, sound);
		markUsed(key);
		return sound;
	}

	public static function clearUnused()
	{
		for (key in [for (k in graphics.keys()) k])
		{
			if (!localKeys.contains(key) && !exclusions.contains(key))
			{
				destroyGraphic(graphics.get(key));
				graphics.remove(key);
			}
		}
		System.gc();
	}

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStored()
	{
		for (key in [for (k in FlxG.bitmap._cache.keys()) k])
			if (!graphics.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));

		for (key in [for (k in sounds.keys()) k])
		{
			if (!localKeys.contains(key) && !exclusions.contains(key) && sounds.get(key) != null)
			{
				LimeAssets.cache.clear(key);
				sounds.remove(key);
			}
		}

		localKeys = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphics()
	{
		var protectedGraphics:Array<FlxGraphic> = [];
		function collect(target:Dynamic)
		{
			if (target == null) return;
			var members:Array<Dynamic> = try Reflect.getProperty(target, 'members') catch (e:Dynamic) null;
			if (members != null)
			{
				for (member in members) collect(member);
				return;
			}
			var graphic:FlxGraphic = try Reflect.getProperty(target, 'graphic') catch (e:Dynamic) null;
			if (graphic != null) protectedGraphics.push(graphic);
		}

		for (member in FlxG.state.members) collect(member);
		if (FlxG.state.subState != null)
			for (member in FlxG.state.subState.members) collect(member);

		for (key in [for (k in graphics.keys()) k])
		{
			if (exclusions.contains(key)) continue;
			var graphic:FlxGraphic = graphics.get(key);
			if (!protectedGraphics.contains(graphic))
			{
				destroyGraphic(graphic);
				graphics.remove(key);
			}
		}
	}

	public static function destroyGraphic(graphic:FlxGraphic)
	{
		if (graphic == null) return;
		if (graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}
}
