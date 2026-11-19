package funkin.data.stage;

import funkin.data.DataUtil;
import funkin.graphics.FrameLoader;
import funkin.data.stage.StageData;
import funkin.data.stage.StageData.StageFile;
import openfl.utils.AssetType;

class StageParser
{
	public static inline final VERSION:String = "2.0.0";
	public static inline final DEFAULT_FILTERS:Int = 3;
	public static final INLINE_KEYS:Array<String> = ['position', 'camera', 'scroll', 'scale', 'offset', 'indices', 'frameSize'];
	static final CHARACTER_TYPES:Map<String, String> = [
		'boyfriend' => 'boyfriend', 'boyfriendGroup' => 'boyfriend', 'bf' => 'boyfriend',
		'dad' => 'dad', 'dadGroup' => 'dad', 'opponent' => 'dad',
		'gf' => 'gf', 'gfGroup' => 'gf', 'girlfriend' => 'gf'
	];

	public static function path(name:String):String
		return Paths.getPath('stages/$name.json', TEXT, null, true);

	public static function exists(name:String):Bool
		return name != null && Paths.exists(path(name), TEXT);

	public static function load(name:String):StageFile
	{
		if (name == null) return null;
		var raw:String = Paths.getContent(path(name));
		return raw != null ? parse(raw) : null;
	}

	public static function parse(raw:String):StageFile
		return fromData(DataUtil.parseJson(raw));

	public static function fromData(data:Dynamic):StageFile
	{
		if (data == null) return null;
		if (Reflect.field(data, 'version') != null && Reflect.field(data, 'characters') != null && Reflect.field(data, 'props') == null) return fromV2(data);
		if (Reflect.field(data, 'props') != null || Reflect.field(data, 'cameraZoom') != null) return fromVSlice(data);
		return normalize(data);
	}

	public static function normalize(data:Dynamic):StageFile
	{
		var file:StageFile = StageData.dummy();
		for (field in Reflect.fields(data))
			Reflect.setField(file, field, Reflect.field(data, field));
		if (file.stageUI == null || file.stageUI.trim().length == 0)
			file.stageUI = file.isPixelStage == true ? 'pixel' : 'normal';
		if (file.camera_speed == null) file.camera_speed = 1;
		return file;
	}

	public static function fromV2(data:Dynamic):StageFile
	{
		var characters:Dynamic = data.characters;
		var bf:Dynamic = character(characters, ['boyfriend', 'bf', 'player']);
		var dad:Dynamic = character(characters, ['opponent', 'dad']);
		var gf:Dynamic = character(characters, ['girlfriend', 'gf']);
		var editor:Dynamic = data.editor;

		var file:StageFile = {
			directory: data.directory != null ? Std.string(data.directory) : '',
			defaultZoom: DataUtil.toFloat(data.zoom, 0.9),
			stageUI: data.ui != null ? Std.string(data.ui) : 'normal',
			boyfriend: cast DataUtil.vector(bf != null ? bf.position : null, 770, 100),
			girlfriend: cast DataUtil.vector(gf != null ? gf.position : null, 400, 130),
			opponent: cast DataUtil.vector(dad != null ? dad.position : null, 100, 100),
			hide_girlfriend: gf != null && DataUtil.toBool(gf.hidden),
			camera_boyfriend: DataUtil.vector(bf != null ? bf.camera : null),
			camera_opponent: DataUtil.vector(dad != null ? dad.camera : null),
			camera_girlfriend: DataUtil.vector(gf != null ? gf.camera : null),
			camera_speed: DataUtil.toFloat(data.cameraSpeed, 1),
			preload: data.preload,
			objects: [for (object in (data.objects != null ? (cast data.objects:Array<Dynamic>) : [])) objectFromV2(object)],
			_editorMeta: {
				boyfriend: editor != null && editor.boyfriend != null ? editor.boyfriend : 'bf',
				gf: editor != null && editor.girlfriend != null ? editor.girlfriend : 'gf',
				dad: editor != null && editor.opponent != null ? editor.opponent : 'dad'
			}
		};
		return file;
	}

	static function character(characters:Dynamic, names:Array<String>):Dynamic
		return DataUtil.field(characters, names);

	public static function objectFromV2(object:Dynamic):Dynamic
	{
		var type:String = object.type != null ? Std.string(object.type) : 'sprite';
		if (CHARACTER_TYPES.exists(type)) return {type: CHARACTER_TYPES.get(type)};

		var render:Dynamic = object.render;
		var position:Array<Float> = DataUtil.vector(object.position);
		var legacy:Dynamic = {
			type: type,
			name: object.name,
			x: position[0],
			y: position[1],
			scale: DataUtil.vector(object.scale, 1, 1),
			scroll: DataUtil.vector(object.scroll, 1, 1),
			alpha: DataUtil.toFloat(object.alpha, 1),
			angle: DataUtil.toFloat(object.angle, 0),
			color: object.color != null ? Std.string(object.color).replace('#', '') : 'FFFFFF',
			filters: DataUtil.toInt(object.filters, DEFAULT_FILTERS)
		};
		if (type != 'square')
		{
			legacy.image = render != null ? FrameLoader.joinImages(render.image) : FrameLoader.joinImages(object.image);
			legacy.antialiasing = render == null || render.antialiasing != false;
			legacy.flipX = DataUtil.toBool(object.flipX);
			legacy.flipY = DataUtil.toBool(object.flipY);
			if (render != null && render.type != null) legacy.render_type = FrameLoader.normalizeType(render.type);
			if (render != null && render.frameSize != null) legacy.frame_size = DataUtil.intVector(render.frameSize);
			if (type == 'animatedSprite')
			{
				legacy.animations = [for (anim in (object.animations != null ? (cast object.animations:Array<Dynamic>) : [])) animationFromV2(anim)];
				legacy.firstAnimation = object.firstAnimation;
			}
		}
		return legacy;
	}

	static function animationFromV2(anim:Dynamic):Dynamic
	{
		var offset:Array<Int> = DataUtil.intVector(DataUtil.field(anim, ['offset', 'offsets']));
		return {
			anim: Std.string(anim.name),
			name: DataUtil.field(anim, ['prefix', 'symbol']) != null ? Std.string(DataUtil.field(anim, ['prefix', 'symbol'])) : '',
			fps: DataUtil.toInt(DataUtil.field(anim, ['fps', 'frameRate']), 24),
			loop: DataUtil.toBool(DataUtil.field(anim, ['loop', 'looped'])),
			indices: DataUtil.intArray(DataUtil.field(anim, ['indices', 'frameIndices'])),
			offsets: offset != null ? offset : [0, 0]
		};
	}

	public static function fromVSlice(data:Dynamic):StageFile
	{
		var entries:Array<{z:Float, order:Int, object:Dynamic}> = [];
		var order:Int = 0;
		var characters:Dynamic = data.characters;
		var file:StageFile = StageData.dummy();
		file.directory = data.directory != null ? Std.string(data.directory) : '';
		file.defaultZoom = DataUtil.toFloat(data.cameraZoom, 1);
		file.stageUI = 'normal';

		for (pair in [['bf', 'boyfriend'], ['dad', 'dad'], ['gf', 'gf']])
		{
			var info:Dynamic = characters != null ? Reflect.field(characters, pair[0]) : null;
			if (info == null) continue;
			var position:Array<Float> = DataUtil.vector(info.position);
			var camera:Array<Float> = DataUtil.vector(info.cameraOffsets);
			switch (pair[1])
			{
				case 'boyfriend':
					file.boyfriend = cast position;
					file.camera_boyfriend = camera;
				case 'dad':
					file.opponent = cast position;
					file.camera_opponent = camera;
				default:
					file.girlfriend = cast position;
					file.camera_girlfriend = camera;
			}
			entries.push({z: DataUtil.toFloat(info.zIndex, 0), order: order++, object: {type: pair[1]}});
		}

		var props:Array<Dynamic> = data.props != null ? data.props : [];
		var isPixelStage:Bool = false;
		for (prop in props)
		{
			var asset:String = prop.assetPath != null ? Std.string(prop.assetPath) : '';
			var colon:Int = asset.indexOf(':');
			if (colon > -1) asset = asset.substr(colon + 1);
			var position:Array<Float> = DataUtil.vector(prop.position);
			var scale:Array<Float> = DataUtil.vector(prop.scale, 1, 1);
			var isPixel:Bool = DataUtil.toBool(prop.isPixel);
			if (isPixel) isPixelStage = true;

			var object:Dynamic = {
				name: prop.name,
				x: position[0],
				y: position[1],
				scale: scale,
				scroll: DataUtil.vector(prop.scroll, 1, 1),
				alpha: DataUtil.toFloat(prop.alpha, 1),
				angle: DataUtil.toFloat(prop.angle, 0),
				color: 'FFFFFF',
				filters: DEFAULT_FILTERS
			};

			if (asset.startsWith('#'))
			{
				object.type = 'square';
				object.color = asset.substr(1);
			}
			else
			{
				var anims:Array<Dynamic> = prop.animations != null ? prop.animations : [];
				object.type = anims.length > 0 ? 'animatedSprite' : 'sprite';
				object.image = asset;
				object.antialiasing = !isPixel;
				object.flipX = DataUtil.toBool(prop.flipX);
				object.flipY = DataUtil.toBool(prop.flipY);
				if (prop.animType != null) object.render_type = FrameLoader.normalizeType(prop.animType);
				if (anims.length > 0)
				{
					object.animations = [for (anim in anims) animationFromV2(anim)];
					object.firstAnimation = prop.startingAnimation;
				}
			}
			entries.push({z: DataUtil.toFloat(prop.zIndex, 0), order: order++, object: object});
		}

		entries.sort(function(a, b) return a.z != b.z ? (a.z < b.z ? -1 : 1) : a.order - b.order);
		file.objects = [for (entry in entries) entry.object];
		if (isPixelStage) file.stageUI = 'pixel';
		return file;
	}

	public static function toV2(file:StageFile):Dynamic
	{
		var meta:Dynamic = file._editorMeta;
		var girlfriend:Dynamic = {position: file.girlfriend, camera: file.camera_girlfriend};
		if (file.hide_girlfriend == true) girlfriend.hidden = true;

		var ui:String = file.stageUI;
		if (ui == null || ui.trim().length == 0) ui = file.isPixelStage == true ? 'pixel' : 'normal';

		var data:Dynamic = {
			version: VERSION,
			directory: file.directory != null ? file.directory : '',
			zoom: file.defaultZoom,
			ui: ui,
			cameraSpeed: file.camera_speed != null ? file.camera_speed : 1,
			characters: {
				boyfriend: {position: file.boyfriend, camera: file.camera_boyfriend},
				girlfriend: girlfriend,
				opponent: {position: file.opponent, camera: file.camera_opponent}
			}
		};
		if (file.preload != null) data.preload = file.preload;
		if (file.objects != null && file.objects.length > 0) data.objects = [for (object in file.objects) objectToV2(object)];
		if (meta != null) data.editor = {boyfriend: meta.boyfriend, girlfriend: meta.gf, opponent: meta.dad};
		return data;
	}

	public static function objectToV2(object:Dynamic):Dynamic
	{
		var type:String = object.type;
		if (CHARACTER_TYPES.exists(type))
			return {type: switch (CHARACTER_TYPES.get(type)) { case 'gf': 'girlfriend'; case 'dad': 'opponent'; default: 'boyfriend'; }};

		var data:Dynamic = {
			name: object.name,
			type: type,
			position: [DataUtil.toFloat(object.x), DataUtil.toFloat(object.y)],
			scale: DataUtil.vector(object.scale, 1, 1),
			scroll: DataUtil.vector(object.scroll, 1, 1)
		};
		if (object.alpha != null && object.alpha != 1) data.alpha = object.alpha;
		if (object.angle != null && object.angle != 0) data.angle = object.angle;
		if (object.color != null && Std.string(object.color).toUpperCase() != 'FFFFFF') data.color = '#' + Std.string(object.color).replace('#', '');
		if (object.filters != null && object.filters != (DEFAULT_FILTERS)) data.filters = object.filters;

		if (type != 'square')
		{
			var images:Array<String> = FrameLoader.splitImages(object.image);
			var render:Dynamic = {
				type: object.render_type != null ? object.render_type : 'auto',
				image: images.length == 1 ? (images[0]:Dynamic) : (images:Dynamic),
				antialiasing: object.antialiasing != false
			};
			if (object.frame_size != null) render.frameSize = object.frame_size;
			data.render = render;
			if (object.flipX == true) data.flipX = true;
			if (object.flipY == true) data.flipY = true;
			if (type == 'animatedSprite')
			{
				var anims:Array<Dynamic> = object.animations != null ? object.animations : [];
				data.animations = [for (anim in anims) {
					var entry:Dynamic = {
						name: anim.anim,
						prefix: anim.name,
						fps: anim.fps,
						loop: anim.loop == true,
						offset: anim.offsets != null && anim.offsets.length > 1 ? [anim.offsets[0], anim.offsets[1]] : [0, 0]
					};
					if (anim.indices != null && anim.indices.length > 0) entry.indices = anim.indices;
					entry;
				}];
				if (object.firstAnimation != null) data.firstAnimation = object.firstAnimation;
			}
		}
		return data;
	}

	public static function stringify(file:StageFile):String
		return DataUtil.stringify(toV2(file), INLINE_KEYS);
}
