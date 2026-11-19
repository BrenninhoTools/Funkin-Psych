package funkin.data.level;

import funkin.data.DataUtil;
import funkin.data.level.LevelData.LevelFile;

class LevelParser
{
	public static inline final VERSION:String = "2.0.0";
	public static final INLINE_KEYS:Array<String> = ['difficulties'];

	public static function isV2(data:Dynamic):Bool
		return data != null && Reflect.field(data, 'version') != null && Reflect.field(data, 'weekCharacters') == null;

	public static function parse(raw:String):LevelFile
		return fromData(DataUtil.parseJson(raw));

	public static function fromData(data:Dynamic):LevelFile
	{
		if (data == null) return null;
		if (isV2(data)) return fromV2(data);
		return normalize(data);
	}

	public static function normalize(data:Dynamic):LevelFile
	{
		var file:LevelFile = LevelData.createLevelFile();
		for (field in Reflect.fields(data))
			Reflect.setField(file, field, Reflect.field(data, field));
		if (file.songs == null) file.songs = [];
		if (file.weekCharacters == null) file.weekCharacters = ['', 'bf', 'gf'];
		return file;
	}

	public static function fromV2(data:Dynamic):LevelFile
	{
		var characters:Dynamic = data.characters;
		var unlock:Dynamic = data.unlock;
		var visibility:Dynamic = data.visibility;
		var songs:Array<Dynamic> = data.songs != null ? data.songs : [];

		var difficulties:Dynamic = data.difficulties;
		var diffString:String = '';
		if (difficulties != null)
		{
			if (Std.isOfType(difficulties, Array)) diffString = (cast difficulties:Array<Dynamic>).map(Std.string).join(', ');
			else diffString = Std.string(difficulties);
		}

		return {
			songs: [for (song in songs) songFromV2(song)],
			weekCharacters: [
				stringField(characters, ['opponent', 'dad']),
				stringField(characters, ['player', 'boyfriend', 'bf']),
				stringField(characters, ['girlfriend', 'gf'])
			],
			weekBackground: data.background != null ? Std.string(data.background) : '',
			weekBefore: unlock != null && unlock.after != null ? Std.string(unlock.after) : '',
			storyName: data.title != null ? Std.string(data.title) : '',
			weekName: data.name != null ? Std.string(data.name) : '',
			startUnlocked: unlock == null || unlock.locked != true,
			hiddenUntilUnlocked: unlock != null && unlock.hidden == true,
			hideStoryMode: visibility != null && visibility.storyMode == false,
			hideFreeplay: visibility != null && visibility.freeplay == false,
			difficulties: diffString
		};
	}

	static function stringField(data:Dynamic, names:Array<String>):String
	{
		var value:Dynamic = data != null ? DataUtil.field(data, names) : null;
		return value != null ? Std.string(value) : '';
	}

	static function songFromV2(song:Dynamic):Array<Dynamic>
	{
		if (Std.isOfType(song, Array)) return cast song;
		if (Std.isOfType(song, String)) return [song, 'face', [146, 113, 253]];
		return [
			song.name != null ? Std.string(song.name) : 'Unknown',
			song.icon != null ? Std.string(song.icon) : 'face',
			DataUtil.rgb(song.color, [146, 113, 253])
		];
	}

	public static function toV2(file:LevelFile):Dynamic
	{
		var chars:Array<String> = file.weekCharacters != null ? file.weekCharacters : ['', '', ''];
		var data:Dynamic = {
			version: VERSION,
			name: file.weekName,
			title: file.storyName,
			background: file.weekBackground,
			characters: {
				opponent: chars.length > 0 ? chars[0] : '',
				player: chars.length > 1 ? chars[1] : '',
				girlfriend: chars.length > 2 ? chars[2] : ''
			},
			songs: [for (song in (file.songs != null ? file.songs : [])) {
				var entry:Array<Dynamic> = song;
				var color:Array<Int> = DataUtil.rgb(entry[2], [146, 113, 253]);
				{name: entry[0], icon: entry[1], color: DataUtil.hex(color)};
			}]
		};

		if (file.difficulties != null && file.difficulties.trim().length > 0)
			data.difficulties = [for (diff in file.difficulties.split(',')) if (diff.trim().length > 0) diff.trim()];

		var unlock:Dynamic = {};
		var hasUnlock:Bool = false;
		if (file.startUnlocked == false) { unlock.locked = true; hasUnlock = true; }
		if (file.hiddenUntilUnlocked == true) { unlock.hidden = true; hasUnlock = true; }
		if (file.weekBefore != null && file.weekBefore.length > 0) { unlock.after = file.weekBefore; hasUnlock = true; }
		if (hasUnlock) data.unlock = unlock;

		if (file.hideStoryMode == true || file.hideFreeplay == true)
			data.visibility = {storyMode: file.hideStoryMode != true, freeplay: file.hideFreeplay != true};
		return data;
	}

	public static function stringify(file:LevelFile):String
		return DataUtil.stringify(toV2(file), INLINE_KEYS);
}
