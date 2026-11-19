package funkin.data.ui;

import flixel.FlxObject;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import funkin.data.DataUtil;
import funkin.graphics.FrameLoader;
import openfl.utils.AssetType;

class UIData
{
	static var cache:Map<String, Dynamic> = [];

	public var id(default, null):String;
	public var data(default, null):Dynamic;

	public function new(id:String, data:Dynamic)
	{
		this.id = id;
		this.data = data != null ? data : {};
	}

	public static function clearFileCache()
		cache.clear();

	public static function fileExists(folder:String, id:String):Bool
		return id != null && id.length > 0 && Paths.exists(filePath(folder, id), TEXT);

	public static function filePath(folder:String, id:String):String
		return Paths.getPath('data/$folder/$id.json', TEXT, null, true);

	public static function readFile(folder:String, id:String):Dynamic
	{
		var key:String = '$folder/$id';
		if (cache.exists(key)) return cache.get(key);
		var parsed:Dynamic = null;
		if (fileExists(folder, id))
		{
			try
			{
				parsed = DataUtil.parseJson(Paths.getContent(filePath(folder, id)));
			}
			catch (e:Dynamic) {}
		}
		cache.set(key, parsed);
		return parsed;
	}

	public static function loadMerged(folder:String, id:String, defaults:Dynamic, ?defaultId:String):Dynamic
	{
		var chain:Array<Dynamic> = [];
		var current:String = id;
		var visited:Array<String> = [];
		while (current != null && !visited.contains(current))
		{
			visited.push(current);
			var raw:Dynamic = readFile(folder, current);
			if (raw == null) break;
			chain.unshift(raw);
			current = raw.fallback != null ? Std.string(raw.fallback) : (defaultId != null && current != defaultId ? defaultId : null);
		}
		for (layer in chain) defaults = merge(defaults, layer);
		return defaults;
	}

	public static function merge(base:Dynamic, layer:Dynamic):Dynamic
	{
		for (field in Reflect.fields(layer))
		{
			if (field == 'fallback' || field == 'version') continue;
			var value:Dynamic = Reflect.field(layer, field);
			var current:Dynamic = Reflect.field(base, field);
			if (isObject(value) && isObject(current))
			{
				var copy:Dynamic = {};
				for (key in Reflect.fields(current)) Reflect.setField(copy, key, Reflect.field(current, key));
				for (key in Reflect.fields(value)) Reflect.setField(copy, key, Reflect.field(value, key));
				Reflect.setField(base, field, copy);
			}
			else Reflect.setField(base, field, value);
		}
		return base;
	}

	static function isObject(value:Dynamic):Bool
		return value != null && Type.typeof(value) == TObject;

	public function element(name:String):Dynamic
	{
		var value:Dynamic = Reflect.field(data, name);
		return value != null ? value : {};
	}

	public function visible(name:String):Bool
		return element(name).visible != false;

	public function float(name:String, field:String, fallback:Float):Float
		return DataUtil.toFloat(Reflect.field(element(name), field), fallback);

	public function int(name:String, field:String, fallback:Int):Int
		return DataUtil.toInt(Reflect.field(element(name), field), fallback);

	public function bool(name:String, field:String, fallback:Bool):Bool
	{
		var value:Dynamic = Reflect.field(element(name), field);
		return value != null ? DataUtil.toBool(value) : fallback;
	}

	public function string(name:String, field:String, fallback:String):String
	{
		var value:Dynamic = Reflect.field(element(name), field);
		return value != null ? Std.string(value) : fallback;
	}

	public function vector(name:String, field:String, defaultX:Float = 0, defaultY:Float = 0):Array<Float>
		return DataUtil.vector(Reflect.field(element(name), field), defaultX, defaultY);

	public function colorOf(name:String, field:String, fallback:FlxColor):FlxColor
		return parseColor(Reflect.field(element(name), field), fallback);

	public function image(name:String, fallback:String):String
		return string(name, 'image', fallback);

	public function width(name:String, fallback:Float):Float
	{
		var value:Float = float(name, 'width', fallback);
		return value <= 0 ? FlxG.width + value : value;
	}

	public function position(name:String):Array<Float>
	{
		var info:Dynamic = element(name);
		var pos:Dynamic = Save.data.downScroll && info.downscroll != null ? info.downscroll : info.position;
		return DataUtil.vector(pos);
	}

	public function place(object:FlxObject, name:String, ?anchor:FlxObject)
	{
		var info:Dynamic = element(name);
		var pos:Array<Float> = position(name);
		var x:Float = pos[0];
		var y:Float = pos[1];
		if (anchor != null)
		{
			y += anchor.y + anchor.height * DataUtil.toFloat(info.anchorHeight, 0);
			if (DataUtil.toBool(info.anchorX)) x += anchor.x;
		}
		object.setPosition(x, y);
		if (DataUtil.toBool(info.centerX)) object.screenCenter(X);
		if (DataUtil.toBool(info.centerY)) object.screenCenter(Y);
		if (info.offset != null)
		{
			var offset:Array<Float> = DataUtil.vector(info.offset);
			object.x += offset[0];
			object.y += offset[1];
		}
		var scroll:Array<Float> = DataUtil.vector(info.scroll, 0, 0);
		object.scrollFactor.set(scroll[0], scroll[1]);
	}

	public function font(name:String):String
		return string(name, 'font', data.font != null ? Std.string(data.font) : 'vcr.ttf');

	public function createText(name:String, text:String, defaultWidth:Float, defaultSize:Int, ?anchor:FlxObject):FlxText
	{
		var info:Dynamic = element(name);
		var field:FlxText = new FlxText(0, 0, width(name, defaultWidth), text, defaultSize);
		var align:FlxTextAlign = switch (string(name, 'alignment', 'center').toLowerCase())
		{
			case 'left': LEFT;
			case 'right': RIGHT;
			case 'justify': JUSTIFY;
			default: CENTER;
		};
		var border:FlxTextBorderStyle = string(name, 'border', 'outline').toLowerCase() == 'none' ? FlxTextBorderStyle.NONE : FlxTextBorderStyle.OUTLINE;
		field.setFormat(Paths.font(font(name)), Std.int(float(name, 'size', defaultSize)), parseColor(info.color, FlxColor.WHITE), align, border, parseColor(info.borderColor, FlxColor.BLACK));
		field.borderSize = float(name, 'borderSize', 1);
		field.antialiasing = bool(name, 'antialiasing', Save.data.antialiasing);
		if (info.alpha != null) field.alpha = DataUtil.toFloat(info.alpha, 1);
		place(field, name, anchor);
		return field;
	}

	public static function parseColor(value:Dynamic, fallback:FlxColor):FlxColor
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Int)) return (value:Int);
		var text:String = DataUtil.colorString(Std.string(value));
		var parsed:Null<FlxColor> = FlxColor.fromString(text);
		return parsed != null ? parsed : fallback;
	}

	public static function format(text:String, values:Map<String, Dynamic>):String
	{
		if (text == null) return null;
		for (key => value in values) text = text.replace('{$key}', Std.string(value));
		return text;
	}

	public static function createSprite(info:Dynamic, ?anchors:Map<String, FlxObject>):FlxSprite
	{
		if (info == null) return null;
		var sprite:FlxSprite = new FlxSprite();
		var render:Dynamic = info.render != null ? info.render : info;
		var imageName:String = FrameLoader.joinImages(render.image);
		if (imageName == null || imageName.length == 0)
		{
			if (info.size == null) return null;
			var size:Array<Float> = DataUtil.vector(info.size, 1, 1);
			sprite.makeGraphic(1, 1, FlxColor.WHITE);
			sprite.scale.set(size[0], size[1]);
			sprite.updateHitbox();
		}
		else
		{
			var type:String = FrameLoader.resolveType(imageName, render.type);
			if (!FrameLoader.apply(sprite, imageName, type, DataUtil.intVector(render.frameSize)))
				sprite.loadGraphic(Paths.image(imageName));

			var anims:Array<Dynamic> = info.animations != null ? info.animations : [];
			for (anim in anims)
				FrameLoader.addAnimation(sprite, Std.string(anim.name), anim.prefix, DataUtil.intArray(anim.indices), DataUtil.toFloat(anim.fps, 24), DataUtil.toBool(anim.loop), type);
			if (info.firstAnimation != null && sprite.animation.exists(info.firstAnimation)) sprite.animation.play(info.firstAnimation);
			else if (anims.length > 0) sprite.animation.play(Std.string(anims[0].name));

			var scale:Array<Float> = DataUtil.vector(info.scale, 1, 1);
			sprite.scale.set(scale[0], scale[1]);
			sprite.updateHitbox();
		}

		sprite.antialiasing = info.antialiasing != false && Save.data.antialiasing;
		if (info.alpha != null) sprite.alpha = DataUtil.toFloat(info.alpha, 1);
		if (info.angle != null) sprite.angle = DataUtil.toFloat(info.angle, 0);
		sprite.flipX = DataUtil.toBool(info.flipX);
		sprite.flipY = DataUtil.toBool(info.flipY);
		if (info.color != null) sprite.color = parseColor(info.color, FlxColor.WHITE);

		var pos:Array<Float> = DataUtil.vector(Save.data.downScroll && info.downscroll != null ? info.downscroll : info.position);
		var anchor:FlxObject = info.anchor != null && anchors != null ? anchors.get(Std.string(info.anchor)) : null;
		sprite.setPosition(pos[0] + (anchor != null && DataUtil.toBool(info.anchorX) ? anchor.x : 0), pos[1] + (anchor != null ? anchor.y : 0));
		if (DataUtil.toBool(info.centerX)) sprite.screenCenter(X);
		if (DataUtil.toBool(info.centerY)) sprite.screenCenter(Y);
		var scroll:Array<Float> = DataUtil.vector(info.scroll, 0, 0);
		sprite.scrollFactor.set(scroll[0], scroll[1]);
		return sprite;
	}

	public function createSprites(group:FlxSpriteGroup, anchors:Map<String, FlxObject>, front:Bool, ?variables:Map<String, Dynamic>)
	{
		var list:Array<Dynamic> = data.sprites != null ? data.sprites : [];
		for (info in list)
		{
			if (info == null || DataUtil.toBool(info.front) != front) continue;
			var sprite:FlxSprite = createSprite(info, anchors);
			if (sprite == null) continue;
			if (info.name != null && variables != null) variables.set(Std.string(info.name), sprite);
			group.add(sprite);
		}
	}
}
