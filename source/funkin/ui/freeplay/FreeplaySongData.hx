package funkin.ui.freeplay;

import funkin.save.Highscore;
import haxe.Json;
import openfl.utils.Assets;

class FreeplaySongData
{
	static var songInfo:Map<String, Dynamic> = null;
	static var favorites:Array<String> = null;

	public var songName(default, null):String;
	public var songId(default, null):String;
	public var icon(default, null):String;
	public var color(default, null):FlxColor;
	public var levelId(default, null):String;
	public var levelIndex(default, null):Int;
	public var folder(default, null):String;
	public var difficulties(default, null):Array<String>;
	public var album(default, null):String;
	public var bpm(get, never):Float;
	public var isFav(get, never):Bool;
	public var lastDifficulty:String = null;

	var ratings:Map<String, Int> = new Map();
	var _bpm:Null<Float> = null;

	public function new(entry:Array<Dynamic>, level:LevelData, levelIndex:Int)
	{
		songName = Std.string(entry[0]);
		songId = Paths.formatToSongPath(songName);
		icon = entry[1] != null ? Std.string(entry[1]) : 'face';
		var rgb:Array<Int> = entry[2];
		color = rgb != null && rgb.length >= 3 ? FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]) : 0xFF9271FD;
		levelId = level.fileName;
		this.levelIndex = levelIndex;
		folder = level.folder != null ? level.folder : '';
		difficulties = Difficulty.parse(level.difficulties);
		if (difficulties.length < 1) difficulties = Difficulty.defaultList.copy();

		var info:Dynamic = getInfo(songId);
		album = entry.length > 3 && entry[3] != null ? Std.string(entry[3]) : (info != null && info.album != null ? Std.string(info.album) : null);
		if (info != null && info.ratings != null)
			for (field in Reflect.fields(info.ratings))
				ratings.set(normalize(field), Std.int(Reflect.field(info.ratings, field)));
	}

	public static function reloadInfo()
	{
		songInfo = new Map();
		var raw:String = Paths.getTextFromFile('data/ui/freeplay/songs.json');
		if (raw == null) return;
		try
		{
			var data:Dynamic = Json.parse(raw);
			var songs:Dynamic = data.songs != null ? data.songs : data;
			for (field in Reflect.fields(songs))
				songInfo.set(normalize(field), Reflect.field(songs, field));
		}
		catch (e:Dynamic) {}
	}

	static function getInfo(id:String):Dynamic
	{
		if (songInfo == null) reloadInfo();
		return songInfo.get(normalize(id));
	}

	static inline function normalize(value:String):String
		return ~/[^a-z0-9]/g.replace(value.toLowerCase(), '');

	public function diffIndex(diff:String):Int
	{
		if (diff == null) return -1;
		var target:String = normalize(diff);
		for (i => entry in difficulties)
			if (normalize(entry) == target) return i;
		return -1;
	}

	public inline function hasDifficulty(diff:String):Bool
		return diffIndex(diff) > -1;

	public function getRating(diff:String):Int
	{
		var rating:Null<Int> = ratings.get(normalize(diff));
		return rating != null ? rating : 0;
	}

	public function getScore(diff:String):Int
	{
		var index:Int = diffIndex(diff);
		if (index < 0) return 0;
		var previous:Array<String> = Difficulty.list;
		Difficulty.list = difficulties;
		var score:Int = Highscore.getScore(songName, index);
		Difficulty.list = previous;
		return score;
	}

	public function getAccuracy(diff:String):Float
	{
		var index:Int = diffIndex(diff);
		if (index < 0) return 0;
		var previous:Array<String> = Difficulty.list;
		Difficulty.list = difficulties;
		var accuracy:Float = Highscore.hasScore(songName, index) ? Highscore.getRating(songName, index) : -1;
		Difficulty.list = previous;
		return accuracy;
	}

	public function getRank(diff:String):Null<FreeplayRank.RankType>
	{
		var accuracy:Float = getAccuracy(diff);
		if (accuracy < 0) return null;
		if (accuracy >= 1) return PERFECT_GOLD;
		if (accuracy >= 0.98) return PERFECT;
		if (accuracy >= 0.9) return EXCELLENT;
		if (accuracy >= 0.8) return GREAT;
		if (accuracy >= 0.6) return GOOD;
		return LOSS;
	}

	function get_bpm():Float
	{
		if (_bpm != null) return _bpm;
		_bpm = 100;
		var previous:String = Mods.currentModDirectory;
		Mods.currentModDirectory = folder;
		var path:String = Paths.json('songs/$songId/$songId');
		var raw:String = null;
		try
		{
			#if sys
			if (FileSystem.exists(path)) raw = File.getContent(path);
			else
			#end
			if (Assets.exists(path, TEXT)) raw = Assets.getText(path);
		}
		catch (e:Dynamic) {}
		Mods.currentModDirectory = previous;

		var regex:EReg = ~/"bpm"\s*:\s*([0-9.]+)/;
		if (raw != null && regex.match(raw))
		{
			var parsed:Float = Std.parseFloat(regex.matched(1));
			if (!Math.isNaN(parsed) && parsed > 0) _bpm = parsed;
		}
		return _bpm;
	}

	static function loadFavorites()
	{
		if (favorites != null) return;
		var saved:Dynamic = Save.main.get('freeplayFavorites');
		favorites = saved != null && Std.isOfType(saved, Array) ? cast saved : [];
	}

	function get_isFav():Bool
	{
		loadFavorites();
		return favorites.contains('$folder:$songId');
	}

	public function toggleFavorite():Bool
	{
		loadFavorites();
		var key:String = '$folder:$songId';
		if (favorites.contains(key)) favorites.remove(key);
		else favorites.push(key);
		Save.main.set('freeplayFavorites', favorites);
		Save.flush();
		return favorites.contains(key);
	}

	public function matchesLetter(filter:String):Bool
	{
		var first:String = songName.charAt(0).toUpperCase();
		switch (filter)
		{
			case null | 'ALL':
				return true;
			case 'fav':
				return isFav;
			case '#':
				return ~/^[0-9]/.match(first);
		}
		var range:Array<String> = filter.split('-');
		if (range.length < 2) return first == range[0].toUpperCase();
		return first >= range[0].toUpperCase() && first <= range[1].toUpperCase();
	}
}
