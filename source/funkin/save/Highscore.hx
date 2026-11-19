package funkin.save;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();

	public static function load():Void
	{
		weekScores = loadMap('weekScores');
		songScores = loadMap('songScores');
		songRating = loadMap('songRating');
	}

	static function loadMap<T>(key:String):Map<String, T>
	{
		var saved:Dynamic = Save.main.get(key);
		return saved != null && Std.isOfType(saved, haxe.Constraints.IMap) ? cast saved : new Map<String, T>();
	}

	public static function flush():Void
	{
		Save.main.set('weekScores', weekScores);
		Save.main.set('songScores', songScores);
		Save.main.set('songRating', songRating);
		Save.flush();
	}

	public static inline function formatSong(song:String, diff:Int):String
		return Paths.formatToSongPath(song) + Difficulty.getFilePath(diff);

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Bool
	{
		if (song == null) return false;
		var key:String = formatSong(song, diff);
		if (songScores.exists(key) && songScores.get(key) >= score) return false;
		songScores.set(key, score);
		if (rating >= 0) songRating.set(key, rating);
		flush();
		return true;
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Bool
	{
		if (week == null) return false;
		var key:String = formatSong(week, diff);
		if (weekScores.exists(key) && weekScores.get(key) >= score) return false;
		weekScores.set(key, score);
		flush();
		return true;
	}

	public static inline function saveLevelScore(level:String, score:Int = 0, ?diff:Int = 0):Bool
		return saveWeekScore(level, score, diff);

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var key:String = formatSong(song, diff);
		songScores.set(key, 0);
		songRating.set(key, 0);
		flush();
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		weekScores.set(formatSong(week, diff), 0);
		flush();
	}

	public static inline function resetLevel(level:String, diff:Int = 0):Void
		resetWeek(level, diff);

	public static function resetAll():Void
	{
		weekScores.clear();
		songScores.clear();
		songRating.clear();
		flush();
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var key:String = formatSong(song, diff);
		return songScores.exists(key) ? songScores.get(key) : 0;
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var key:String = formatSong(song, diff);
		return songRating.exists(key) ? songRating.get(key) : 0;
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var key:String = formatSong(week, diff);
		return weekScores.exists(key) ? weekScores.get(key) : 0;
	}

	public static inline function getLevelScore(level:String, diff:Int):Int
		return getWeekScore(level, diff);

	public static function hasScore(song:String, diff:Int):Bool
		return songScores.exists(formatSong(song, diff));
}
