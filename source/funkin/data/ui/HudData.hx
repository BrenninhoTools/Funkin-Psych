package funkin.data.ui;

import openfl.utils.AssetType;

class HudData extends UIData
{
	public static inline final VERSION:String = "1.0.0";
	public static inline final DEFAULT:String = 'default';
	public static inline final FOLDER:String = 'ui';

	public function new(id:String, data:Dynamic)
		super(id, data);

	public static function defaults():Dynamic
	{
		return {
			version: VERSION,
			font: 'vcr.ttf',
			camera: {zoom: 1, angle: 0, bump: 0.03},
			healthBar: {image: 'healthBar', position: [0, 641], downscroll: [0, 79], centerX: true, leftToRight: false, barOffset: [3, 3]},
			icons: {offsetY: -75, spacing: 26},
			timeText: {position: [434, 19], downscroll: [434, 676], width: 400, size: 32, borderSize: 2},
			timeBar: {image: 'timeBar', anchor: 'timeText', anchorHeight: 0.25, position: [0, 0], centerX: true},
			scoreText: {anchor: 'healthBar', position: [0, 40], width: 0, size: 20, borderSize: 1.25},
			botplayText: {anchor: 'healthBar', position: [400, -90], downscroll: [400, 70], width: -800, size: 32, borderSize: 1.25},
			sprites: []
		};
	}

	public static function exists(id:String):Bool
		return UIData.fileExists(FOLDER, id);

	public static function clearCache()
		UIData.clearFileCache();

	public static function load(id:String):HudData
		return new HudData(id, UIData.loadMerged(FOLDER, id, defaults(), DEFAULT));

	public static function resolveId():String
	{
		var song = PlayState.SONG;
		if (song != null && song.hud != null && song.hud.trim().length > 0 && exists(song.hud.trim())) return song.hud.trim();
		var ui:String = PlayState.stageUI;
		if (ui != null && ui.length > 0 && exists(ui)) return ui;
		return DEFAULT;
	}

	public static function resolve():HudData
		return load(resolveId());

	public function scoreFormat():String
	{
		var text:Dynamic = element('scoreText').format;
		return text != null && Std.string(text).length > 0 ? Std.string(text) : null;
	}

	public function formatScore(values:Map<String, Dynamic>):String
		return UIData.format(scoreFormat(), values);
}
