package funkin.data.song;

import funkin.data.song.Song;
import funkin.data.song.Song.SwagSong;
import funkin.data.song.Song.SwagSection;
import funkin.data.DataUtil;

class ChartParser
{
	public static inline final VERSION:String = "2.0.0";
	public static inline final FORMAT:String = 'psych_v1';
	public static final INLINE_KEYS:Array<String> = ['notes', 'values'];

	public static function isV2(data:Dynamic):Bool
		return data != null && Reflect.field(data, 'version') != null && (Reflect.field(data, 'sections') != null || Reflect.field(data, 'characters') != null || isEventList(Reflect.field(data, 'events')));

	static function isEventList(events:Dynamic):Bool
	{
		if (events == null || !Std.isOfType(events, Array)) return false;
		var list:Array<Dynamic> = events;
		return list.length > 0 && !Std.isOfType(list[0], Array);
	}

	public static function fromV2(data:Dynamic):SwagSong
	{
		var characters:Dynamic = data.characters;
		var gameOver:Dynamic = data.gameOver;
		var styles:Dynamic = data.noteStyle;

		var song:SwagSong = {
			song: data.song != null ? Std.string(data.song) : 'Unknown',
			notes: [],
			events: [],
			bpm: DataUtil.toFloat(data.bpm, 100),
			needsVoices: data.needsVoices != false,
			speed: DataUtil.toFloat(data.speed, 1),
			offset: DataUtil.toFloat(data.offset, 0),
			player1: characterField(characters, ['player', 'boyfriend', 'bf'], 'bf'),
			player2: characterField(characters, ['opponent', 'dad'], 'dad'),
			gfVersion: characterField(characters, ['girlfriend', 'gf'], 'gf'),
			stage: data.stage != null ? Std.string(data.stage) : 'stage',
			format: FORMAT
		};

		if (gameOver != null)
		{
			if (gameOver.character != null) song.gameOverChar = gameOver.character;
			if (gameOver.sound != null) song.gameOverSound = gameOver.sound;
			if (gameOver.loop != null) song.gameOverLoop = gameOver.loop;
			if (gameOver.end != null) song.gameOverEnd = gameOver.end;
		}
		if (DataUtil.toBool(data.disableNoteRGB)) song.disableNoteRGB = true;
		if (data.variation != null && Std.string(data.variation).length > 0) song.variation = Std.string(data.variation);
		if (data.arrowSkin != null) song.arrowSkin = data.arrowSkin;
		if (data.splashSkin != null) song.splashSkin = data.splashSkin;
		if (data.hud != null) song.hud = data.hud;

		if (styles != null)
		{
			if (Std.isOfType(styles, String)) song.noteStyle = styles;
			else
			{
				if (styles.base != null) song.noteStyle = styles.base;
				if (styles.player != null) song.playerNoteStyle = styles.player;
				if (styles.opponent != null) song.opponentNoteStyle = styles.opponent;
			}
		}

		var sections:Array<Dynamic> = data.sections != null ? data.sections : [];
		for (section in sections)
		{
			var swag:SwagSection = {
				sectionNotes: [],
				sectionBeats: DataUtil.toFloat(section.beats, 4),
				mustHitSection: section.mustHit != false
			};
			if (DataUtil.toBool(section.altAnim)) swag.altAnim = true;
			if (DataUtil.toBool(section.gfSection)) swag.gfSection = true;
			if (section.bpm != null)
			{
				swag.bpm = DataUtil.toFloat(section.bpm, song.bpm);
				swag.changeBPM = DataUtil.toBool(section.changeBpm);
			}

			var notes:Array<Dynamic> = section.notes != null ? section.notes : [];
			for (note in notes)
				swag.sectionNotes.push(noteFromV2(note));
			song.notes.push(swag);
		}

		song.events = eventsFromV2(data.events);
		return song;
	}

	static function characterField(characters:Dynamic, names:Array<String>, fallback:String):String
	{
		var value:Dynamic = characters != null ? DataUtil.field(characters, names) : null;
		return value != null ? Std.string(value) : fallback;
	}

	static function noteFromV2(note:Dynamic):Array<Dynamic>
	{
		if (Std.isOfType(note, Array)) return cast note;
		var lane:Int = DataUtil.toInt(DataUtil.field(note, ['lane', 'data', 'd']), 0);
		var data:Array<Dynamic> = [
			DataUtil.toFloat(DataUtil.field(note, ['time', 't']), 0),
			lane,
			DataUtil.toFloat(DataUtil.field(note, ['length', 'l']), 0)
		];
		var type:Dynamic = DataUtil.field(note, ['type', 'k']);
		if (type != null && Std.string(type).length > 0) data.push(Std.string(type));
		return data;
	}

	public static function eventsFromV2(events:Dynamic):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];
		if (events == null) return result;
		var list:Array<Dynamic> = events;
		var byTime:Map<String, Array<Dynamic>> = [];
		for (event in list)
		{
			if (Std.isOfType(event, Array))
			{
				result.push(event);
				continue;
			}
			var time:Float = DataUtil.toFloat(event.time, 0);
			var values:Array<Dynamic> = event.values != null ? event.values : [];
			var entry:Array<Dynamic> = [
				event.name != null ? Std.string(event.name) : '',
				values.length > 0 && values[0] != null ? Std.string(values[0]) : '',
				values.length > 1 && values[1] != null ? Std.string(values[1]) : ''
			];
			var key:String = Std.string(time);
			if (!byTime.exists(key))
			{
				var group:Array<Dynamic> = [];
				byTime.set(key, group);
				result.push([time, group]);
			}
			byTime.get(key).push(entry);
		}
		result.sort(function(a, b) return a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0));
		return result;
	}

	public static function toV2(song:SwagSong):Dynamic
	{
		var data:Dynamic = {
			version: VERSION,
			song: song.song,
			bpm: song.bpm,
			speed: song.speed,
			offset: song.offset,
			needsVoices: song.needsVoices != false,
			stage: song.stage,
			characters: {player: song.player1, opponent: song.player2, girlfriend: song.gfVersion}
		};

		var styles:Dynamic = {};
		var hasStyle:Bool = false;
		if (song.noteStyle != null && song.noteStyle.length > 0) { styles.base = song.noteStyle; hasStyle = true; }
		if (song.playerNoteStyle != null && song.playerNoteStyle.length > 0) { styles.player = song.playerNoteStyle; hasStyle = true; }
		if (song.opponentNoteStyle != null && song.opponentNoteStyle.length > 0) { styles.opponent = song.opponentNoteStyle; hasStyle = true; }
		if (hasStyle) data.noteStyle = styles;

		if (song.arrowSkin != null && song.arrowSkin.length > 0) data.arrowSkin = song.arrowSkin;
		if (song.splashSkin != null && song.splashSkin.length > 0) data.splashSkin = song.splashSkin;
		if (song.disableNoteRGB == true) data.disableNoteRGB = true;
		if (song.variation != null && song.variation.length > 0) data.variation = song.variation;
		if (song.hud != null && song.hud.length > 0) data.hud = song.hud;

		var gameOver:Dynamic = {};
		var hasGameOver:Bool = false;
		for (pair in [['character', song.gameOverChar], ['sound', song.gameOverSound], ['loop', song.gameOverLoop], ['end', song.gameOverEnd]])
		{
			if (pair[1] != null && pair[1].length > 0)
			{
				Reflect.setField(gameOver, pair[0], pair[1]);
				hasGameOver = true;
			}
		}
		if (hasGameOver) data.gameOver = gameOver;

		if (song.notes != null)
			data.sections = [for (section in song.notes) sectionToV2(section)];
		data.events = eventsToV2(song.events);
		return data;
	}

	static function sectionToV2(section:SwagSection):Dynamic
	{
		var data:Dynamic = {
			beats: section.sectionBeats,
			mustHit: section.mustHitSection
		};
		if (section.gfSection == true) data.gfSection = true;
		if (section.altAnim == true) data.altAnim = true;
		if (section.changeBPM == true)
		{
			data.changeBpm = true;
			data.bpm = section.bpm;
		}
		var notes:Array<Dynamic> = [];
		if (section.sectionNotes != null)
		{
			for (raw in section.sectionNotes)
			{
				var note:Array<Dynamic> = raw;
				var entry:Dynamic = {time: note[0], lane: note[1]};
				var length:Float = DataUtil.toFloat(note[2], 0);
				if (length > 0) entry.length = length;
				if (note.length > 3 && note[3] != null && Std.string(note[3]).length > 0) entry.type = Std.string(note[3]);
				notes.push(entry);
			}
		}
		data.notes = notes;
		return data;
	}

	public static function eventsToV2(events:Array<Dynamic>):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];
		if (events == null) return result;
		for (group in events)
		{
			var time:Float = DataUtil.toFloat(group[0], 0);
			var entries:Array<Dynamic> = group[1];
			if (entries == null) continue;
			for (entry in entries)
				result.push({time: time, name: entry[0], values: [entry[1], entry[2]]});
		}
		return result;
	}

	public static function stringify(song:SwagSong):String
		return DataUtil.stringify(toV2(song), INLINE_KEYS);

	public static function stringifyEvents(events:Array<Dynamic>):String
		return DataUtil.stringify({version: VERSION, events: eventsToV2(events)}, ['values']);
}
