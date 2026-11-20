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
	public var difficulties(default, null):Array<String> = [];
	public var baseDifficulties(default, null):Array<String>;
	public var player(default, null):String = 'bf';
	public var available(get, never):Bool;
	public var album(default, null):String;
	public var bpm(get, never):Float;
	public var isFav(get, never):Bool;
	public var lastDifficulty:String = null;

	var ratings:Map<String, Int> = new Map();
	var bpmCache:Map<String, Float> = new Map();
	var variants:Array<FreeplayVariant> = [];
	var charts:Map<String, FreeplayVariant> = new Map();
	var baseIcon:String;

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
		baseDifficulties = Difficulty.parse(level.difficulties);
		if (baseDifficulties.length < 1) baseDifficulties = Difficulty.defaultList.copy();
		baseIcon = icon;

		var info:Dynamic = getInfo(songId);
		album = entry.length > 3 && entry[3] != null ? Std.string(entry[3]) : (info != null && info.album != null ? Std.string(info.album) : null);
		if (info != null && info.ratings != null)
			for (field in Reflect.fields(info.ratings))
				ratings.set(normalize(field), Std.int(Reflect.field(info.ratings, field)));

		var basePlayer:String = info != null && info.player != null ? Std.string(info.player) : 'bf';
		variants.push({song: songName, difficulties: baseDifficulties, player: basePlayer, icon: null, ratings: null, audio: songId, variation: null});
		var extra:Array<Dynamic> = info != null && info.variants != null ? info.variants : [];
		for (entry in extra)
		{
			if (entry == null || entry.song == null) continue;
			var diffs:Array<String> = [];
			var rawDiffs:Array<Dynamic> = entry.difficulties != null ? entry.difficulties : [];
			for (diff in rawDiffs) diffs.push(Std.string(diff));
			if (diffs.length < 1) diffs = Difficulty.defaultList.copy();
			var variantRatings:Map<String, Int> = null;
			if (entry.ratings != null)
			{
				variantRatings = new Map();
				for (field in Reflect.fields(entry.ratings)) variantRatings.set(normalize(field), Std.int(Reflect.field(entry.ratings, field)));
			}
			variants.push({
				song: Std.string(entry.song),
				difficulties: diffs,
				player: entry.player != null ? Std.string(entry.player) : 'bf',
				icon: entry.icon != null ? Std.string(entry.icon) : null,
				ratings: variantRatings,
				audio: entry.audio != null ? Std.string(entry.audio) : songId,
				variation: entry.variation != null ? Std.string(entry.variation) : null
			});
		}
		setPlayer('bf');
	}

	public function setPlayer(id:String)
	{
		player = id;
		difficulties = [];
		charts.clear();
		icon = baseIcon;
		var iconSet:Bool = false;
		for (variant in variants)
		{
			if (variant.player != id) continue;
			if (!iconSet && variant.icon != null)
			{
				icon = variant.icon;
				iconSet = true;
			}
			for (diff in variant.difficulties)
			{
				var key:String = normalize(diff);
				if (charts.exists(key)) continue;
				charts.set(key, variant);
				difficulties.push(diff);
			}
		}
	}

	inline function get_available():Bool
		return difficulties.length > 0;

	public function chartFor(diff:String):FreeplayChart
	{
		if (diff == null) return null;
		var variant:FreeplayVariant = charts.get(normalize(diff));
		if (variant == null) return null;
		var target:String = normalize(diff);
		for (i => entry in variant.difficulties)
			if (normalize(entry) == target) return {song: Paths.formatToSongPath(variant.song), list: variant.difficulties, index: i};
		return null;
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
		var chart:FreeplayChart = chartFor(diff);
		return chart != null ? chart.index : -1;
	}

	public inline function hasDifficulty(diff:String):Bool
		return diff != null && charts.exists(normalize(diff));

	public function previewFor(diff:String):{audio:String, variation:String}
	{
		var variant:FreeplayVariant = diff != null ? charts.get(normalize(diff)) : null;
		if (variant == null) return {audio: songId, variation: null};
		return {audio: Paths.formatToSongPath(variant.audio), variation: variant.variation};
	}

	public function songIdFor(diff:String):String
	{
		var chart:FreeplayChart = chartFor(diff);
		return chart != null ? chart.song : songId;
	}

	public function getRating(diff:String):Int
	{
		var variant:FreeplayVariant = diff != null ? charts.get(normalize(diff)) : null;
		if (variant != null && variant.ratings != null && variant.ratings.exists(normalize(diff))) return variant.ratings.get(normalize(diff));
		var rating:Null<Int> = ratings.get(normalize(diff));
		return rating != null ? rating : 0;
	}

	public function getScore(diff:String):Int
	{
		var chart:FreeplayChart = chartFor(diff);
		if (chart == null) return 0;
		var previous:Array<String> = Difficulty.list;
		Difficulty.list = chart.list;
		var score:Int = Highscore.getScore(chart.song, chart.index);
		Difficulty.list = previous;
		return score;
	}

	public function getAccuracy(diff:String):Float
	{
		var chart:FreeplayChart = chartFor(diff);
		if (chart == null) return -1;
		var previous:Array<String> = Difficulty.list;
		Difficulty.list = chart.list;
		var accuracy:Float = Highscore.hasScore(chart.song, chart.index) ? Highscore.getRating(chart.song, chart.index) : -1;
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
		return bpmFor(null);

	public function bpmFor(diff:String):Float
	{
		if (diff == null) diff = difficulties.length > 0 ? difficulties[0] : null;
		var chart:FreeplayChart = chartFor(diff);
		var id:String = chart != null ? chart.song : songId;
		var suffix:String = '';
		if (chart != null)
		{
			var name:String = Paths.formatToSongPath(chart.list[chart.index]);
			if (name != Paths.formatToSongPath(Difficulty.getDefault())) suffix = '-$name';
		}
		var cacheKey:String = id + suffix;
		if (bpmCache.exists(cacheKey)) return bpmCache.get(cacheKey);
		var value:Float = 100;
		var previous:String = Mods.currentModDirectory;
		Mods.currentModDirectory = folder;
		var raw:String = null;
		for (path in [Paths.json('songs/$id/$id$suffix'), Paths.json('songs/$id/$id')])
		{
			try
			{
				#if sys
				if (FileSystem.exists(path)) raw = File.getContent(path);
				else
				#end
				if (Assets.exists(path, TEXT)) raw = Assets.getText(path);
			}
			catch (e:Dynamic) {}
			if (raw != null) break;
		}
		Mods.currentModDirectory = previous;

		var regex:EReg = ~/"bpm"\s*:\s*([0-9.]+)/;
		if (raw != null && regex.match(raw))
		{
			var parsed:Float = Std.parseFloat(regex.matched(1));
			if (!Math.isNaN(parsed) && parsed > 0) value = parsed;
		}
		bpmCache.set(cacheKey, value);
		return value;
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

typedef FreeplayVariant =
{
	song:String,
	difficulties:Array<String>,
	player:String,
	icon:String,
	ratings:Map<String, Int>,
	audio:String,
	variation:String
}

typedef FreeplayChart =
{
	song:String,
	list:Array<String>,
	index:Int
}
