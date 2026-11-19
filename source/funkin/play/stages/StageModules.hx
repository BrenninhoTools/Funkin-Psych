package funkin.play.stages;

import funkin.play.stages.modules.*;

class StageModules
{
	static var pendingOptions:Dynamic = null;

	public static final registry:Map<String, Void->BaseStage> = [
		'dadbattleSpotlight' => () -> new DadBattleSpotlight(),
		'phillyGlow' => () -> new PhillyGlow(),
		'schoolDialogue' => () -> new SchoolDialogue(),
		'limo' => () -> new Limo(),
		'tank' => () -> new Tank(),
		'phillyStreets' => () -> new PhillyStreets(),
		'phillyBlazin' => () -> new PhillyBlazin()
	];

	public static function exists(name:String):Bool
		return name != null && registry.exists(name);

	public static function create(entry:Dynamic):BaseStage
	{
		var name:String = Std.isOfType(entry, String) ? entry : (entry != null && entry.name != null ? Std.string(entry.name) : null);
		if (!exists(name))
		{
			FlxG.log.warn('Unknown stage module "$name"');
			return null;
		}
		pendingOptions = Std.isOfType(entry, String) ? {} : (entry.options != null ? entry.options : {});
		var stage:BaseStage = registry.get(name)();
		pendingOptions = null;
		return stage;
	}

	public static function consumeOptions():Dynamic
	{
		var options:Dynamic = pendingOptions != null ? pendingOptions : {};
		pendingOptions = null;
		return options;
	}
}
