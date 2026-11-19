package funkin.data.character;

import funkin.data.DataUtil;
import openfl.utils.AssetType;
import funkin.graphics.FrameLoader;
import funkin.objects.Character.CharacterFile;
import funkin.objects.Character.AnimArray;

class CharacterParser
{
	public static inline final VERSION:String = "2.0.0";
	public static final INLINE_KEYS:Array<String> = ['offset', 'position', 'camera', 'color', 'indices', 'frameSize'];

	public static function path(name:String):String
		return Paths.getPath('characters/$name.json', TEXT, null, true);

	public static function exists(name:String):Bool
		return name != null && Paths.exists(path(name), TEXT);

	public static function load(name:String):CharacterFile
	{
		if (name == null) return null;
		var raw:String = Paths.getContent(path(name));
		return raw != null ? parse(raw) : null;
	}

	public static function parse(raw:String):CharacterFile
		return fromData(DataUtil.parseJson(raw));

	public static function fromData(data:Dynamic):CharacterFile
	{
		if (data == null) return null;
		if (Reflect.field(data, 'render') != null) return fromV2(data);
		if (Reflect.field(data, 'assetPath') != null || Reflect.field(data, 'renderType') != null) return fromVSlice(data);
		return normalize(data);
	}

	public static function normalize(data:Dynamic):CharacterFile
	{
		var animations:Array<AnimArray> = [];
		var rawAnims:Array<Dynamic> = Reflect.field(data, 'animations');
		if (rawAnims != null)
			for (anim in rawAnims)
				animations.push({
					anim: Std.string(anim.anim),
					name: anim.name != null ? Std.string(anim.name) : '',
					fps: DataUtil.toInt(anim.fps, 24),
					loop: DataUtil.toBool(anim.loop),
					indices: DataUtil.intArray(anim.indices),
					offsets: DataUtil.intArray(anim.offsets).length > 1 ? DataUtil.intArray(anim.offsets) : [0, 0]
				});

		return {
			animations: animations,
			image: FrameLoader.joinImages(Reflect.field(data, 'image')),
			scale: DataUtil.toFloat(Reflect.field(data, 'scale'), 1),
			sing_duration: DataUtil.toFloat(Reflect.field(data, 'sing_duration'), 4),
			healthicon: Reflect.field(data, 'healthicon') != null ? Std.string(Reflect.field(data, 'healthicon')) : 'face',
			position: DataUtil.vector(Reflect.field(data, 'position')),
			camera_position: DataUtil.vector(Reflect.field(data, 'camera_position')),
			flip_x: DataUtil.toBool(Reflect.field(data, 'flip_x')),
			no_antialiasing: DataUtil.toBool(Reflect.field(data, 'no_antialiasing')),
			healthbar_colors: DataUtil.rgb(Reflect.field(data, 'healthbar_colors')),
			vocals_file: Reflect.field(data, 'vocals_file') != null ? Std.string(Reflect.field(data, 'vocals_file')) : '',
			_editor_isPlayer: Reflect.field(data, '_editor_isPlayer'),
			render_type: Reflect.field(data, 'render_type'),
			frame_size: DataUtil.intVector(Reflect.field(data, 'frame_size'))
		};
	}

	public static function fromV2(data:Dynamic):CharacterFile
	{
		var render:Dynamic = data.render;
		var icon:Dynamic = data.healthIcon;
		var iconId:String = 'face';
		var iconColor:Dynamic = data.healthColor;
		if (icon != null)
		{
			if (Std.isOfType(icon, String)) iconId = icon;
			else
			{
				if (icon.id != null) iconId = Std.string(icon.id);
				if (icon.color != null) iconColor = icon.color;
			}
		}

		var animations:Array<AnimArray> = [];
		var rawAnims:Array<Dynamic> = data.animations;
		if (rawAnims != null)
			for (anim in rawAnims)
			{
				var offset:Array<Int> = DataUtil.intVector(DataUtil.field(anim, ['offset', 'offsets']));
				animations.push({
					anim: Std.string(anim.name),
					name: DataUtil.field(anim, ['prefix', 'symbol']) != null ? Std.string(DataUtil.field(anim, ['prefix', 'symbol'])) : '',
					fps: DataUtil.toInt(DataUtil.field(anim, ['fps', 'frameRate']), 24),
					loop: DataUtil.toBool(DataUtil.field(anim, ['loop', 'looped'])),
					indices: DataUtil.intArray(DataUtil.field(anim, ['indices', 'frames'])),
					offsets: offset != null ? offset : [0, 0]
				});
			}

		var editor:Dynamic = data.editor;
		return {
			animations: animations,
			image: FrameLoader.joinImages(render.image),
			scale: DataUtil.toFloat(render.scale, 1),
			sing_duration: DataUtil.toFloat(data.singDuration, 4),
			healthicon: iconId,
			position: DataUtil.vector(data.position),
			camera_position: DataUtil.vector(data.camera),
			flip_x: DataUtil.toBool(render.flipX),
			no_antialiasing: render.antialiasing == false,
			healthbar_colors: DataUtil.rgb(iconColor),
			vocals_file: data.vocals != null ? Std.string(data.vocals) : '',
			_editor_isPlayer: editor != null ? editor.isPlayer : null,
			render_type: render.type != null ? FrameLoader.normalizeType(render.type) : null,
			frame_size: DataUtil.intVector(render.frameSize)
		};
	}

	public static function fromVSlice(data:Dynamic):CharacterFile
	{
		var image:String = Std.string(data.assetPath);
		var colon:Int = image.indexOf(':');
		if (colon > -1) image = image.substr(colon + 1);

		var animations:Array<AnimArray> = [];
		var rawAnims:Array<Dynamic> = data.animations;
		if (rawAnims != null)
			for (anim in rawAnims)
			{
				var offset:Array<Int> = DataUtil.intVector(anim.offsets);
				animations.push({
					anim: Std.string(anim.name),
					name: anim.prefix != null ? Std.string(anim.prefix) : '',
					fps: DataUtil.toInt(anim.frameRate, 24),
					loop: DataUtil.toBool(anim.looped),
					indices: DataUtil.intArray(anim.frameIndices),
					offsets: offset != null ? offset : [0, 0]
				});
			}

		var icon:Dynamic = data.healthIcon;
		var singTime:Float = DataUtil.toFloat(data.singTime, 8);
		var isPixel:Bool = DataUtil.toBool(data.isPixel);
		return {
			animations: animations,
			image: image,
			scale: DataUtil.toFloat(data.scale, 1),
			sing_duration: Math.max(1, singTime / 1.1),
			healthicon: icon != null && icon.id != null ? Std.string(icon.id) : 'face',
			position: DataUtil.vector(data.offsets),
			camera_position: DataUtil.vector(data.cameraOffsets),
			flip_x: DataUtil.toBool(data.flipX),
			no_antialiasing: isPixel,
			healthbar_colors: DataUtil.rgb(data.healthbarColor),
			vocals_file: '',
			_editor_isPlayer: null,
			render_type: data.renderType != null ? FrameLoader.normalizeType(data.renderType) : null,
			frame_size: null
		};
	}

	public static function toV2(file:CharacterFile, ?isPlayer:Null<Bool>):Dynamic
	{
		var images:Array<String> = FrameLoader.splitImages(file.image);
		var render:Dynamic = {
			type: file.render_type != null ? file.render_type : 'auto',
			image: images.length == 1 ? images[0] : images,
			scale: file.scale,
			flipX: file.flip_x == true,
			antialiasing: file.no_antialiasing != true
		};
		if (file.frame_size != null) render.frameSize = file.frame_size;

		var data:Dynamic = {
			version: VERSION,
			render: render,
			position: file.position,
			camera: file.camera_position,
			healthIcon: {id: file.healthicon, color: DataUtil.hex(file.healthbar_colors)},
			singDuration: file.sing_duration,
			animations: [for (anim in (file.animations != null ? file.animations : [])) animationToV2(anim)]
		};
		if (file.vocals_file != null && file.vocals_file.length > 0) data.vocals = file.vocals_file;
		var player:Null<Bool> = isPlayer != null ? isPlayer : file._editor_isPlayer;
		if (player != null) data.editor = {isPlayer: player};
		return data;
	}

	public static function animationToV2(anim:AnimArray):Dynamic
	{
		var data:Dynamic = {
			name: anim.anim,
			prefix: anim.name,
			fps: anim.fps,
			loop: anim.loop == true,
			offset: anim.offsets != null && anim.offsets.length > 1 ? [anim.offsets[0], anim.offsets[1]] : [0, 0]
		};
		if (anim.indices != null && anim.indices.length > 0) data.indices = anim.indices;
		return data;
	}

	public static function stringify(file:CharacterFile, ?isPlayer:Null<Bool>):String
		return DataUtil.stringify(toV2(file, isPlayer), INLINE_KEYS);
}
