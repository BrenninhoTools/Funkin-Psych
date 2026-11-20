package funkin.ui.freeplay;

import flxanimate.frames.FlxAnimateFrames;
import funkin.ui.freeplay.FreeplayState.ExitMoverData;
import haxe.Json;

class AlbumRoll extends FlxSpriteGroup
{
	public static inline var DEFAULT_OST_NAME:String = 'OFFICIAL OST';

	public var albumId(default, set):String = null;
	public var difficultyStars(default, null):DifficultyStars;

	var albumArt:FlxAnimate;
	var albumTitle:FlxSprite;
	var albumData:Dynamic = null;
	var spritemap:Dynamic = null;
	var currentAnim:String = null;
	var exitMovers:ExitMoverData;
	var availableAnims:Map<String, Bool> = [];

	public function new()
	{
		super();
		albumArt = new FlxAnimate(FlxG.width - 360, 220);
		Paths.loadAnimateAtlas(albumArt, 'freeplay/albumRoll/freeplayAlbum');
		albumArt.antialiasing = Save.data.antialiasing;
		for (label in ['intro', 'switch', 'idle'])
		{
			try
			{
				if (albumArt.anim.getFrameLabel(label) == null) continue;
				albumArt.anim.addByFrameLabel(label, label, 24, false);
				availableAnims.set(label, true);
			}
			catch (e:Dynamic) {}
		}
		albumArt.anim.onComplete.add(onAlbumFinish);
		albumArt.visible = false;

		var raw:String = Paths.getTextFromFile('images/freeplay/albumRoll/freeplayAlbum/spritemap1.json');
		if (raw != null)
		{
			try
			{
				spritemap = Json.parse(StringTools.replace(raw, String.fromCharCode(0xFEFF), ''));
			}
			catch (e:Dynamic) {}
		}

		difficultyStars = new DifficultyStars(FlxG.width - 330, 209, FlxG.width - 367);
		difficultyStars.visible = false;

		add(albumArt);
		add(difficultyStars);
		buildAlbumTitle('freeplay/albumRoll/volume1-text');
		albumTitle.visible = false;
	}

	function playArt(name:String)
	{
		if (!availableAnims.exists(name)) return;
		currentAnim = name;
		albumArt.anim.play(name, true);
	}

	function onAlbumFinish():Void
	{
		if (albumArt.anim.isPlaying) return;
		playArt('idle');
	}

	function set_albumId(value:String):String
	{
		if (albumId != value || value == null)
		{
			albumId = value;
			updateAlbum();
		}
		return value;
	}

	function updateAlbum():Void
	{
		if (albumId == null)
		{
			visible = false;
			albumData = null;
			return;
		}
		visible = true;

		albumData = null;
		var raw:String = Paths.getTextFromFile('data/ui/freeplay/albums/$albumId.json');
		if (raw != null)
		{
			try
			{
				albumData = Json.parse(raw);
			}
			catch (e:Dynamic) {}
		}
		if (albumData == null) return;

		if (spritemap != null && albumData.albumArtAsset != null)
		{
			var graphic = Paths.image(Std.string(albumData.albumArtAsset));
			if (graphic != null) albumArt.frames = FlxAnimateFrames.fromSpriteMap(cast spritemap, graphic);
		}

		var offsets:Array<Float> = albumData.albumTitleOffsets != null ? albumData.albumTitleOffsets : [0, 0];
		buildAlbumTitle(albumData.albumTitleAsset != null ? Std.string(albumData.albumTitleAsset) : 'freeplay/albumRoll/volume1-text', offsets);
	}

	public function applyExitMovers(movers:ExitMoverData):Void
	{
		exitMovers = movers;
		exitMovers.set([albumArt, difficultyStars], {x: FlxG.width, speed: 0.4, wait: 0});
		if (albumTitle != null) exitMovers.set([albumTitle], {x: FlxG.width, speed: 0.4, wait: 0});
	}

	public function playIntro():Void
	{
		visible = true;
		albumTitle.visible = false;
		albumArt.visible = true;
		playArt('intro');
		difficultyStars.visible = false;
		new FlxTimer().start(0.75, function(_)
		{
			showTitle();
			showStars();
			albumTitle.animation.play('switch');
		});
	}

	public function skipIntro():Void
	{
		visible = true;
		albumArt.visible = true;
		playArt('switch');
		albumTitle.animation.play('switch');
	}

	public function showTitle():Void
		albumTitle.visible = albumTitle.frames != null;

	function buildAlbumTitle(assetKey:String, ?offsets:Array<Float>):Void
	{
		var wasVisible:Bool = albumTitle != null && albumTitle.visible;
		if (albumTitle != null)
		{
			if (exitMovers != null) for (key in exitMovers.keys()) if (key.contains(albumTitle)) exitMovers.remove(key);
			remove(albumTitle, true);
			albumTitle.destroy();
		}
		if (offsets == null) offsets = [0, 0];

		albumTitle = new FlxSprite(FlxG.width - 355 + offsets[0], 500 + offsets[1]);
		albumTitle.frames = Paths.getSparrowAtlas(assetKey);
		albumTitle.antialiasing = Save.data.antialiasing;
		albumTitle.animation.addByPrefix('idle', 'idle0', 24, true);
		albumTitle.animation.addByPrefix('switch', 'switch0', 24, false);
		albumTitle.animation.onFinish.add(function(name:String)
		{
			if (name == 'switch') albumTitle.animation.play('idle');
		});
		albumTitle.animation.play(wasVisible ? 'switch' : 'idle');
		albumTitle.visible = wasVisible;
		add(albumTitle);

		if (exitMovers != null) exitMovers.set([albumTitle], {x: FlxG.width, speed: 0.4, wait: 0});
	}

	public function setDifficultyStars(difficulty:Int):Void
		difficultyStars.difficulty = difficulty;

	public function showStars():Void
	{
		difficultyStars.visible = true;
		difficultyStars.flameCheck();
	}

	public function getOSTName():String
	{
		if (albumId == null) return '';
		if (albumData != null && albumData.ostName != null) return Std.string(albumData.ostName);
		return DEFAULT_OST_NAME;
	}
}
