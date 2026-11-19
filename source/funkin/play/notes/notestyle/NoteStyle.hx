package funkin.play.notes.notestyle;

import funkin.data.DataUtil;
import funkin.graphics.FrameLoader;
import openfl.utils.AssetType;
import funkin.play.notes.Note;
import funkin.play.notes.NoteSplash;

typedef NoteStyleAnimation =
{
	var prefix:String;
	var indices:Array<Int>;
	var fps:Float;
	var loop:Bool;
	var offset:Array<Float>;
}

class NoteStyleAsset
{
	public var image:String;
	public var type:String = 'auto';
	public var frameSize:Array<Int>;
	public var frameCount:Array<Int>;
	public var scale:Float = 1;
	public var antialiasing:Bool = true;
	public var offset:Array<Float> = [0, 0];
	public var animations:Map<String, NoteStyleAnimation> = [];

	public function new() {}

	public static function fromData(data:Dynamic):NoteStyleAsset
	{
		if (data == null) return null;
		var asset:NoteStyleAsset = new NoteStyleAsset();
		var render:Dynamic = data.render != null ? data.render : data;
		asset.image = FrameLoader.joinImages(render.image);
		if (asset.image == null || asset.image.length == 0) return null;
		asset.type = FrameLoader.normalizeType(render.type);
		asset.frameSize = DataUtil.intVector(render.frameSize);
		asset.frameCount = DataUtil.intVector(DataUtil.field(render, ['frameCount', 'grid']));
		asset.scale = DataUtil.toFloat(data.scale, 1);
		asset.antialiasing = data.antialiasing != false && render.antialiasing != false;
		asset.offset = DataUtil.vector(data.offset);

		var anims:Dynamic = data.animations;
		if (anims != null)
		{
			for (key in Reflect.fields(anims))
			{
				var anim:Dynamic = Reflect.field(anims, key);
				if (anim == null) continue;
				if (Std.isOfType(anim, String)) anim = {prefix: anim};
				asset.animations.set(key, {
					prefix: anim.prefix != null ? Std.string(anim.prefix) : '',
					indices: DataUtil.intArray(anim.indices),
					fps: DataUtil.toFloat(DataUtil.field(anim, ['fps', 'frameRate']), 24),
					loop: DataUtil.toBool(DataUtil.field(anim, ['loop', 'looped'])),
					offset: DataUtil.vector(DataUtil.field(anim, ['offset', 'offsets']))
				});
			}
		}
		return asset;
	}
}

class NoteStyle
{
	public static inline final VERSION:String = "1.0.0";
	public static inline final DEFAULT:String = 'funkin';
	public static inline final DEFAULT_PIXEL:String = 'pixel';
	public static final DIRECTIONS:Array<String> = ['left', 'down', 'up', 'right'];

	static var cache:Map<String, NoteStyle> = [];
	static var currentKey:String = null;
	static var currentStyle:NoteStyle = null;

	public var id:String;
	public var name:String;
	public var pixel:Bool = false;
	public var splash:String;
	public var note:NoteStyleAsset;
	public var hold:NoteStyleAsset;
	public var strum:NoteStyleAsset;

	public function new(id:String)
	{
		this.id = id;
		this.name = id;
	}

	public static function path(id:String):String
		return Paths.getPath('data/notestyles/$id.json', TEXT, null, true);

	public static function exists(id:String):Bool
		return id != null && id.length > 0 && Paths.exists(path(id), TEXT);

	public static function get(id:String):NoteStyle
	{
		if (id == null || id.length == 0) return null;
		if (cache.exists(id)) return cache.get(id);

		var style:NoteStyle = null;
		try
		{
			var raw:String = Paths.getContent(path(id));
			if (raw != null) style = fromData(id, DataUtil.parseJson(raw), [id]);
		}
		catch (e:Dynamic)
		{
			style = null;
		}
		cache.set(id, style);
		return style;
	}

	static function fromData(id:String, data:Dynamic, chain:Array<String>):NoteStyle
	{
		if (data == null) return null;
		var style:NoteStyle = new NoteStyle(id);
		if (data.name != null) style.name = Std.string(data.name);
		style.pixel = DataUtil.toBool(data.pixel);
		style.splash = data.splash != null ? Std.string(data.splash) : null;
		style.note = NoteStyleAsset.fromData(data.note);
		style.hold = NoteStyleAsset.fromData(DataUtil.field(data, ['hold', 'sustain']));
		style.strum = NoteStyleAsset.fromData(DataUtil.field(data, ['strum', 'receptor']));

		var fallbackId:String = data.fallback != null ? Std.string(data.fallback) : null;
		if (fallbackId != null && !chain.contains(fallbackId))
		{
			chain.push(fallbackId);
			var raw:String = Paths.getContent(path(fallbackId));
			var fallback:NoteStyle = raw != null ? fromData(fallbackId, DataUtil.parseJson(raw), chain) : null;
			if (fallback != null)
			{
				if (style.note == null) style.note = fallback.note;
				if (style.hold == null) style.hold = fallback.hold;
				if (style.strum == null) style.strum = fallback.strum;
				if (style.splash == null) style.splash = fallback.splash;
				if (data.pixel == null) style.pixel = fallback.pixel;
			}
		}
		return style;
	}

	public static function clearCache()
	{
		cache.clear();
		currentKey = null;
		currentStyle = null;
	}

	public static function resolveId():String
	{
		var song = PlayState.SONG;
		if (song != null)
		{
			if (song.noteStyle != null && song.noteStyle.trim().length > 0) return song.noteStyle.trim();
			if (song.arrowSkin != null && song.arrowSkin.length > 0 && song.arrowSkin != Note.defaultNoteSkin) return null;
		}
		var ui:String = PlayState.stageUI;
		if (ui != null && ui != 'normal' && ui != 'pixel' && exists(ui)) return ui;
		return PlayState.isPixelStage ? DEFAULT_PIXEL : DEFAULT;
	}

	public static function hasSideStyles():Bool
	{
		var song = PlayState.SONG;
		return song != null && ((song.playerNoteStyle != null && song.playerNoteStyle.length > 0) || (song.opponentNoteStyle != null && song.opponentNoteStyle.length > 0));
	}

	public static function sideId(player:Bool):String
	{
		var song = PlayState.SONG;
		if (song == null) return null;
		var id:String = player ? song.playerNoteStyle : song.opponentNoteStyle;
		return id != null && id.trim().length > 0 ? id.trim() : null;
	}

	public static function current(?player:Null<Bool>):NoteStyle
	{
		var id:String = player != null ? sideId(player) : null;
		if (id != null && exists(id)) return get(id);
		id = resolveId();
		var key:String = id + '|' + Mods.currentModDirectory;
		if (key != currentKey)
		{
			currentKey = key;
			currentStyle = get(id);
		}
		return currentStyle;
	}

	public static inline function direction(noteData:Int):String
		return DIRECTIONS[Std.int(Math.abs(noteData)) % DIRECTIONS.length];

	public function imageFor(asset:NoteStyleAsset):String
	{
		var postfix:String = Note.getNoteSkinPostfix();
		if (postfix.length > 0)
		{
			var images:Array<String> = FrameLoader.splitImages(asset.image);
			var custom:Array<String> = [for (image in images) image + postfix];
			var valid:Bool = true;
			for (image in custom)
				if (!Paths.fileExists('images/$image.png', IMAGE)) valid = false;
			if (valid) return custom.join(',');
		}
		return asset.image;
	}

	public function resolvedType(asset:NoteStyleAsset):String
	{
		if (asset.type == 'auto' && asset.frameCount != null) return 'grid';
		return FrameLoader.resolveType(asset.image, asset.type);
	}

	public function loadFrames(sprite:FlxSprite, asset:NoteStyleAsset):Bool
	{
		if (asset == null) return false;
		var image:String = imageFor(asset);
		var type:String = resolvedType(asset);
		var size:Array<Int> = asset.frameSize;
		if (type == 'grid' && size == null)
			size = FrameLoader.gridSize(FrameLoader.splitImages(image)[0], asset.frameCount);
		return FrameLoader.apply(sprite, image, type, size);
	}

	public function hasAnimation(asset:NoteStyleAsset, key:String):Bool
		return asset != null && asset.animations.exists(key);

	public function addAnimation(sprite:FlxSprite, asset:NoteStyleAsset, name:String, key:String):Bool
	{
		if (asset == null || !asset.animations.exists(key)) return false;
		var anim:NoteStyleAnimation = asset.animations.get(key);
		FrameLoader.addAnimation(sprite, name, anim.prefix, anim.indices, anim.fps, anim.loop, resolvedType(asset));
		return sprite.animation.exists(name);
	}

	public function applyScale(sprite:FlxSprite, asset:NoteStyleAsset)
	{
		if (asset.scale != 1)
			sprite.setGraphicSize(Std.int(sprite.frameWidth * asset.scale));
		sprite.updateHitbox();
		sprite.antialiasing = asset.antialiasing && !pixel && ClientPrefs.data.antialiasing;
	}

	public function splashTexture():String
	{
		if (splash == null || splash.length == 0) return null;
		var custom:String = splash + NoteSplash.getSplashSkinPostfix();
		if (Paths.fileExists('images/$custom.png', IMAGE)) return custom;
		return splash;
	}
}
