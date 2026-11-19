package funkin.data.song;

class Difficulty
{
	public static final defaultList:Array<String> = ['Easy', 'Normal', 'Hard'];
	static final defaultDifficulty:String = 'Normal';

	public static var list:Array<String> = [];

	public static function getFilePath(?num:Null<Int>):String
	{
		if (num == null) num = PlayState.storyDifficulty;
		var name:String = list[num];
		if (name == null || Paths.formatToSongPath(name) == Paths.formatToSongPath(defaultDifficulty)) return '';
		return Paths.formatToSongPath('-' + name);
	}

	public static function parse(value:String):Array<String>
	{
		if (value == null) return [];
		return [for (entry in value.split(',')) if (entry.trim().length > 0) entry.trim()];
	}

	public static function loadFromLevel(?level:LevelData)
	{
		if (level == null) level = LevelData.getCurrentLevel();
		var diffs:Array<String> = level != null ? parse(level.difficulties) : [];
		if (diffs.length > 0) list = diffs;
		else resetList();
	}

	public static inline function loadFromWeek(?week:LevelData)
		loadFromLevel(week);

	public static inline function resetList()
		list = defaultList.copy();

	public static inline function copyFrom(diffs:Array<String>)
		list = diffs != null ? diffs.copy() : defaultList.copy();

	public static function getString(?num:Null<Int>, ?canTranslate:Bool = true):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if (diffName == null) diffName = defaultDifficulty;
		return canTranslate ? Language.getPhrase('difficulty_$diffName', diffName) : diffName;
	}

	public static inline function getDefault():String
		return defaultDifficulty;

	public static function indexOf(name:String):Int
	{
		if (name == null) return -1;
		var target:String = Paths.formatToSongPath(name);
		for (i => diff in list)
			if (Paths.formatToSongPath(diff) == target) return i;
		return -1;
	}

	public static inline function exists(name:String):Bool
		return indexOf(name) > -1;

	public static inline function count():Int
		return list.length;
}
