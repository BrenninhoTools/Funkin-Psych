package funkin.graphics;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.graphics.frames.FlxImageFrame;
import flixel.graphics.frames.FlxTileFrames;
import flixel.math.FlxPoint;
import openfl.utils.AssetType;

class FrameLoader
{
	public static final TYPES:Array<String> = ['auto', 'sparrow', 'packer', 'aseprite', 'multisparrow', 'grid', 'image', 'atlas'];

	public static function normalizeType(type:String):String
	{
		if (type == null) return 'auto';
		return switch (type.trim().toLowerCase())
		{
			case 'sparrow', 'xml': 'sparrow';
			case 'packer', 'txt', 'spritesheetpacker': 'packer';
			case 'aseprite', 'json', 'texturepacker': 'aseprite';
			case 'multisparrow', 'multi', 'multiatlas': 'multisparrow';
			case 'grid', 'tiles', 'spritesheet': 'grid';
			case 'image', 'static', 'png', 'graphic': 'image';
			case 'atlas', 'animate', 'animateatlas', 'adobeanimate', 'textureatlas': 'atlas';
			default: 'auto';
		}
	}

	public static function splitImages(image:Dynamic):Array<String>
	{
		if (image == null) return [];
		var list:Array<String> = [];
		if (Std.isOfType(image, Array))
		{
			for (entry in (cast image:Array<Dynamic>))
				if (entry != null) list.push(Std.string(entry).trim());
		}
		else
		{
			for (entry in Std.string(image).split(','))
				list.push(entry.trim());
		}
		return [for (entry in list) if (entry.length > 0) entry];
	}

	public static function joinImages(image:Dynamic):String
		return splitImages(image).join(',');

	public static function isAnimateAtlas(image:Dynamic, ?type:String):Bool
	{
		var kind:String = normalizeType(type);
		if (kind == 'atlas') return true;
		if (kind != 'auto') return false;
		var images:Array<String> = splitImages(image);
		return images.length == 1 && detectType(images) == 'atlas';
	}

	public static function detectType(image:Dynamic):String
	{
		var images:Array<String> = splitImages(image);
		if (images.length == 0) return 'image';
		if (images.length > 1) return 'multisparrow';
		var key:String = images[0];
		if (Paths.fileExists('images/$key.xml', TEXT)) return 'sparrow';
		if (Paths.fileExists('images/$key/Animation.json', TEXT)) return 'atlas';
		if (Paths.fileExists('images/$key.json', TEXT)) return 'aseprite';
		if (Paths.fileExists('images/$key.txt', TEXT)) return 'packer';
		return 'image';
	}

	public static function resolveType(image:Dynamic, ?type:String):String
	{
		var kind:String = normalizeType(type);
		return kind == 'auto' ? detectType(splitImages(image)) : kind;
	}

	public static function load(image:Dynamic, ?type:String, ?frameSize:Array<Int>, ?parentFolder:String, ?allowGPU:Bool = true):FlxFramesCollection
	{
		var images:Array<String> = splitImages(image);
		if (images.length == 0) return null;

		var kind:String = normalizeType(type);
		if (kind == 'auto') kind = detectType(images);

		return switch (kind)
		{
			case 'sparrow':
				images.length > 1 ? Paths.getMultiAtlas(images, parentFolder, allowGPU) : Paths.getSparrowAtlas(images[0], parentFolder, allowGPU);
			case 'packer':
				Paths.getPackerAtlas(images[0], parentFolder, allowGPU);
			case 'aseprite':
				Paths.getAsepriteAtlas(images[0], parentFolder, allowGPU);
			case 'multisparrow':
				Paths.getMultiAtlas(images, parentFolder, allowGPU);
			case 'grid':
				loadGrid(images[0], frameSize, parentFolder, allowGPU);
			case 'atlas':
				null;
			default:
				var graphic:FlxGraphic = Paths.image(images[0], parentFolder, allowGPU);
				graphic != null ? FlxImageFrame.fromGraphic(graphic) : null;
		}
	}

	public static function gridSize(image:String, frameCount:Array<Int>, ?parentFolder:String, ?allowGPU:Bool = true):Array<Int>
	{
		if (frameCount == null || frameCount.length < 1) return null;
		var graphic:FlxGraphic = Paths.image(image, parentFolder, allowGPU);
		if (graphic == null) return null;
		var columns:Int = frameCount[0] > 0 ? frameCount[0] : 1;
		var rows:Int = frameCount.length > 1 && frameCount[1] > 0 ? frameCount[1] : 1;
		return [Math.floor(graphic.width / columns), Math.floor(graphic.height / rows)];
	}

	public static function loadGrid(image:String, ?frameSize:Array<Int>, ?parentFolder:String, ?allowGPU:Bool = true):FlxFramesCollection
	{
		var graphic:FlxGraphic = Paths.image(image, parentFolder, allowGPU);
		if (graphic == null) return null;
		var width:Int = (frameSize != null && frameSize.length > 0 && frameSize[0] > 0) ? frameSize[0] : graphic.height;
		var height:Int = (frameSize != null && frameSize.length > 1 && frameSize[1] > 0) ? frameSize[1] : width;
		var size:FlxPoint = FlxPoint.get(width, height);
		var frames:FlxTileFrames = FlxTileFrames.fromGraphic(graphic, size);
		size.put();
		return frames;
	}

	public static function apply(sprite:FlxSprite, image:Dynamic, ?type:String, ?frameSize:Array<Int>, ?parentFolder:String, ?allowGPU:Bool = true):Bool
	{
		var frames:FlxFramesCollection = load(image, type, frameSize, parentFolder, allowGPU);
		if (frames == null) return false;
		sprite.frames = frames;
		return true;
	}

	public static function usesFrameIndices(?type:String):Bool
	{
		var kind:String = normalizeType(type);
		return kind == 'grid' || kind == 'image';
	}

	public static function addAnimation(sprite:FlxSprite, name:String, prefix:String, ?indices:Array<Int>, fps:Float = 24, loop:Bool = false, ?type:String, flipX:Bool = false, flipY:Bool = false)
	{
		var hasIndices:Bool = indices != null && indices.length > 0;
		if (usesFrameIndices(type) || (hasIndices && (prefix == null || prefix.length == 0)))
			sprite.animation.add(name, hasIndices ? indices : [0], fps, loop, flipX, flipY);
		else if (hasIndices)
			sprite.animation.addByIndices(name, prefix, indices, '', fps, loop, flipX, flipY);
		else
			sprite.animation.addByPrefix(name, prefix, fps, loop, flipX, flipY);
	}
}
