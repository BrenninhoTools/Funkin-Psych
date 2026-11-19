package funkin.data.ui;

import flixel.FlxObject;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import funkin.data.DataUtil;
import funkin.graphics.FrameLoader;
import openfl.utils.AssetType;

class HudData
{
	public static inline final VERSION:String = "1.0.0";
	public static inline final DEFAULT:String = 'default';

	static var cache:Map<String, Dynamic> = [];

	public var id(default, null):String;
	public var data(default, null):Dynamic;

	public function new(id:String, data:Dynamic)
	{
		this.id = id;
		this.data = data != null ? data : {};
	}

	public static function defaults():Dynamic
	{
		return {
			version: VERSION,
			font: 'vcr.ttf',
			camera: {zoom: 1, angle: 0, bump: 0.03},
			healthBar: {image: 'healthBar', position: [0, 641], downscroll: [0, 79], centerX: true, leftToRight: false, barOffset: [3, 3]},
			icons: {offsetY: -75, spacing: 26},
			timeText: {position: [434, 19], downscroll: [434, 676], width: 400, size: 32, borderSize: 2},
			timeBar: {image: 'timeBar', anchor: 'timeText', anchorHeight: 0.25, position: [0, 0], centerX: true},
			scoreText: {anchor: 'healthBar', position: [0, 40], width: 0, size: 20, borderSize: 1.25},
			botplayText: {anchor: 'healthBar', position: [400, -90], downscroll: [400, 70], width: -800, size: 32, borderSize: 1.25},
			sprites: []
		};
	}

	public static function path(id:String):String
		return Paths.getPath('data/ui/$id.json', TEXT, null, true);

	public static function exists(id:String):Bool
		return id != null && id.length > 0 && Paths.exists(path(id), TEXT);

	public static function clearCache()
		cache.clear();

	public static function load(id:String):HudData
	{
		var merged:Dynamic = defaults();
		var chain:Array<Dynamic> = [];
		var current:String = id;
		var visited:Array<String> = [];
		while (current != null && !visited.contains(current))
		{
			visited.push(current);
			var raw:Dynamic = readFile(current);
			if (raw == null) break;
			chain.unshift(raw);
			current = raw.fallback != null ? Std.string(raw.fallback) : (current != DEFAULT ? DEFAULT : null);
		}
		for (layer in chain) merged = merge(merged, layer);
		return new HudData(id, merged);
	}

	static function readFile(id:String):Dynamic
	{
		if (cache.exists(id)) return cache.get(id);
		var parsed:Dynamic = null;
		if (exists(id))
		{
			try
			{
				parsed = DataUtil.parseJson(Paths.getContent(path(id)));
			}
			catch (e:Dynamic) {}
		}
		cache.set(id, parsed);
		return parsed;
	}

	static function merge(base:Dynamic, layer:Dynamic):Dynamic
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

	public static function resolveId():String
	{
		var song = PlayState.SONG;
		if (song != null && song.hud != null && song.hud.trim().length > 0 && exists(song.hud.trim())) return song.hud.trim();
		var ui:String = PlayState.stageUI;
		if (ui != null && ui.length > 0 && exists(ui)) return ui;
		return DEFAULT;
	}

	public static function resolve():HudData
		return load(resolveId());

	public function element(name:String):Dynamic
	{
		var value:Dynamic = Reflect.field(data, name);
		return value != null ? value : {};
	}

	public function visible(name:String):Bool
		return element(name).visible != false;

	public function float(name:String, field:String, fallback:Float):Float
		return DataUtil.toFloat(Reflect.field(element(name), field), fallback);

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
		var pos:Dynamic = ClientPrefs.data.downScroll && info.downscroll != null ? info.downscroll : info.position;
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
		if (info.offset != null)
		{
			var offset:Array<Float> = DataUtil.vector(info.offset);
			object.x += offset[0];
			object.y += offset[1];
		}
		object.scrollFactor.set();
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
		field.setFormat(Paths.font(font(name)), Std.int(float(name, 'size', defaultSize)), color(info.color, FlxColor.WHITE), align, FlxTextBorderStyle.OUTLINE, color(info.borderColor, FlxColor.BLACK));
		field.borderSize = float(name, 'borderSize', 1);
		field.antialiasing = bool(name, 'antialiasing', ClientPrefs.data.antialiasing);
		if (info.alpha != null) field.alpha = DataUtil.toFloat(info.alpha, 1);
		place(field, name, anchor);
		return field;
	}

	static function color(value:Dynamic, fallback:FlxColor):FlxColor
	{
		if (value == null) return fallback;
		var rgb:Array<Int> = DataUtil.rgb(value, null);
		return rgb != null ? FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]) : fallback;
	}

	public function scoreFormat():String
	{
		var format:Dynamic = element('scoreText').format;
		return format != null && Std.string(format).length > 0 ? Std.string(format) : null;
	}

	public function formatScore(values:Map<String, Dynamic>):String
	{
		var text:String = scoreFormat();
		if (text == null) return null;
		for (key => value in values) text = text.replace('{$key}', Std.string(value));
		return text;
	}

	public function createSprites(group:FlxSpriteGroup, anchors:Map<String, FlxObject>, front:Bool)
	{
		var list:Array<Dynamic> = data.sprites != null ? data.sprites : [];
		for (info in list)
		{
			if (info == null || DataUtil.toBool(info.front) != front) continue;
			var sprite:FlxSprite = new FlxSprite();
			var render:Dynamic = info.render != null ? info.render : info;
			var imageName:String = FrameLoader.joinImages(render.image);
			if (imageName == null || imageName.length == 0) continue;
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
			sprite.antialiasing = info.antialiasing != false && ClientPrefs.data.antialiasing;
			if (info.alpha != null) sprite.alpha = DataUtil.toFloat(info.alpha, 1);
			if (info.angle != null) sprite.angle = DataUtil.toFloat(info.angle, 0);
			sprite.flipX = DataUtil.toBool(info.flipX);
			sprite.flipY = DataUtil.toBool(info.flipY);
			if (info.color != null) sprite.color = color(info.color, FlxColor.WHITE);
			if (info.hideWithHud != false) sprite.visible = !ClientPrefs.data.hideHud;

			var pos:Array<Float> = DataUtil.vector(ClientPrefs.data.downScroll && info.downscroll != null ? info.downscroll : info.position);
			var anchor:FlxObject = info.anchor != null && anchors != null ? anchors.get(Std.string(info.anchor)) : null;
			sprite.setPosition(pos[0] + (anchor != null && DataUtil.toBool(info.anchorX) ? anchor.x : 0), pos[1] + (anchor != null ? anchor.y : 0));
			if (DataUtil.toBool(info.centerX)) sprite.screenCenter(X);
			sprite.scrollFactor.set();

			if (info.name != null && PlayState.instance != null)
				PlayState.instance.variables.set(Std.string(info.name), sprite);
			group.add(sprite);
		}
	}
}
