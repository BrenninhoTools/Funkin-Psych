package funkin.data.stage;

import openfl.utils.Assets;
import haxe.Json;
import funkin.data.song.Song;
import funkin.scripting.luascript.ModchartSprite;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;

	@:optional var preload:Dynamic;
	@:optional var objects:Array<Dynamic>;
	@:optional var modules:Array<Dynamic>;
	@:optional var behaviors:Array<Dynamic>;
	@:optional var default_gf:String;
	@:optional var _editorMeta:Dynamic;
}

enum abstract LoadFilters(Int) from Int from UInt to Int to UInt
{
	var LOW_QUALITY:Int = (1 << 0);
	var HIGH_QUALITY:Int = (1 << 1);

	var STORY_MODE:Int = (1 << 2);
	var FREEPLAY:Int = (1 << 3);
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,

			_editorMeta: {
				gf: "gf",
				dad: "dad",
				boyfriend: "bf"
			}
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(Song.loadedSongName != null)
			stage = vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : '';
	}

	public static function getStageFile(stage:String):StageFile {
		try
		{
			var file:StageFile = funkin.data.stage.StageParser.load(stage);
			if (file != null) return file;
		}
		catch (e:Dynamic) {}
		return dummy();
	}

	public static function vanillaSongStage(songName):String
	{
		switch (songName)
		{
			case 'spookeez' | 'south' | 'monster':
				return 'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				return 'philly';
			case 'milf' | 'satin-panties' | 'high':
				return 'limo';
			case 'cocoa' | 'eggnog':
				return 'mall';
			case 'winter-horrorland':
				return 'mallEvil';
			case 'senpai' | 'roses':
				return 'school';
			case 'thorns':
				return 'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				return 'tank';
		}
		return 'stage';
	}

	public static var reservedNames:Array<String> = ['gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup'];
	public static function addObjectsToState(objectList:Array<Dynamic>, gf:FlxSprite, dad:FlxSprite, boyfriend:FlxSprite, ?group:Dynamic = null, ?ignoreFilters:Bool = false)
	{
		var addedObjects:Map<String, FlxSprite> = [];
		for (num => data in objectList)
		{
			if (addedObjects.exists(data)) continue;

			switch(data.type)
			{
				case 'gf', 'gfGroup':
					if(gf != null)
					{
						gf.ID = num; 
						if (group != null) group.add(gf);
						addedObjects.set('gf', gf);
					}
				case 'dad', 'dadGroup':
					if(dad != null)
					{
						dad.ID = num;
						if (group != null) group.add(dad);
						addedObjects.set('dad', dad);
					}
				case 'boyfriend', 'boyfriendGroup':
					if(boyfriend != null)
					{
						boyfriend.ID = num;
						if (group != null) group.add(boyfriend);
						addedObjects.set('boyfriend', boyfriend);
					}

				case 'square', 'sprite', 'animatedSprite':
					if(!ignoreFilters && !validateVisibility(data.filters)) continue;

					var spr:ModchartSprite = new ModchartSprite(data.x, data.y);
					spr.ID = num;
					if(data.type != 'square')
					{
						var renderType:String = data.render_type;
						if (renderType == null && data.type == 'sprite') renderType = 'image';
						renderType = funkin.graphics.FrameLoader.resolveType(data.image, renderType);
						if (!funkin.graphics.FrameLoader.apply(spr, data.image, renderType, data.frame_size))
							spr.loadGraphic(Paths.image(data.image));
						
						if(data.type == 'animatedSprite' && data.animations != null)
						{
							var anims:Array<funkin.play.character.Character.AnimArray> = cast data.animations;
							for (key => anim in anims)
							{
								funkin.graphics.FrameLoader.addAnimation(spr, anim.anim, anim.name, anim.indices, anim.fps, anim.loop, renderType);
	
								if(anim.offsets != null)
									spr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
	
								if(spr.animation.curAnim == null || data.firstAnimation == anim.anim)
									spr.playAnim(anim.anim, true);
							}
						}
						for (varName in ['antialiasing', 'flipX', 'flipY'])
						{
							var dat:Dynamic = Reflect.getProperty(data, varName);
							if(dat != null) Reflect.setProperty(spr, varName, dat);
						}
						if(!Save.data.antialiasing) spr.antialiasing = false;
					}
					else
					{
						spr.makeGraphic(1, 1, FlxColor.WHITE);
						spr.antialiasing = false;
					}

					if(data.scale != null && (data.scale[0] != 1.0 || data.scale[1] != 1.0))
					{
						spr.scale.set(data.scale[0], data.scale[1]);
						if (data.updateHitbox != false) spr.updateHitbox();
					}
					spr.scrollFactor.set(data.scroll[0], data.scroll[1]);
					spr.color = CoolUtil.colorFromString(data.color);
					
					applyExtras(spr, data);
					if (group != null) group.add(spr);
					addedObjects.set(data.name, spr);

				default:
					if(!ignoreFilters && data.filters != null && !validateVisibility(data.filters)) continue;
					var spr:FlxSprite = funkin.play.stages.StagePrefabs.create(data.type, data);
					if (spr == null)
					{
						FlxG.log.error('[Stage .JSON file] Unknown sprite type detected: ${data.type}');
						continue;
					}
					spr.ID = num;
					if (data.scroll != null) spr.scrollFactor.set(data.scroll[0], data.scroll[1]);
					applyExtras(spr, data);
					if (group != null) group.add(spr);
					if (data.name != null) addedObjects.set(data.name, spr);
			}
		}
		return addedObjects;
	}

	public static function applyExtras(spr:FlxSprite, data:Dynamic)
	{
		var size:Array<Dynamic> = data.graphicSize;
		if (size != null && size.length > 0)
		{
			spr.setGraphicSize(Std.int(funkin.data.DataUtil.toFloat(size[0], 0)), size.length > 1 ? Std.int(funkin.data.DataUtil.toFloat(size[1], 0)) : 0);
			spr.updateHitbox();
		}
		for (varName in ['alpha', 'angle', 'visible', 'active'])
		{
			var dat:Dynamic = Reflect.field(data, varName);
			if (dat != null) Reflect.setProperty(spr, varName, dat);
		}
		if (data.blend != null)
		{
			var mode:openfl.display.BlendMode = Std.string(data.blend).toLowerCase();
			spr.blend = mode;
		}
		if (data.velocity != null) spr.velocity.set(data.velocity[0], data.velocity[1]);
	}

	public static function validateVisibility(filters:LoadFilters)
	{
		if((filters & STORY_MODE) == STORY_MODE && !PlayState.isStoryMode) return false;
		if((filters & FREEPLAY) == FREEPLAY && PlayState.isStoryMode) return false;

		return ((Save.data.lowQuality && (filters & LOW_QUALITY) == LOW_QUALITY) ||
			(!Save.data.lowQuality && (filters & HIGH_QUALITY) == HIGH_QUALITY));
	}
}
