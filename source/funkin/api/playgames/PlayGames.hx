package funkin.api.playgames;

import flixel.util.FlxSignal.FlxTypedSignal;
#if android
import lime.system.JNI;
#end

typedef PlayGamesPlayer =
{
	var id:String;
	var name:String;
}

class PlayGames
{
	#if android
	static inline final CLASS:String = 'org/psychengine/playgames/PlayGamesExtension';
	#end
	static inline final MAPPING_FILE:String = 'data/playgames.json';

	public static var supported(get, never):Bool;
	public static var configured(get, never):Bool;
	public static var signedIn(get, never):Bool;
	public static var busy(get, never):Bool;
	public static var player(default, null):PlayGamesPlayer = null;
	public static var lastError(default, null):String = '';

	public static final onSignIn:FlxTypedSignal<PlayGamesPlayer->Void> = new FlxTypedSignal<PlayGamesPlayer->Void>();
	public static final onSignOut:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
	public static final onError:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	static var achievementIds:Map<String, String> = new Map();
	static var leaderboardIds:Map<String, String> = new Map();
	static var pendingAchievements:Array<String> = [];
	static var started:Bool = false;
	static var methods:Map<String, Dynamic> = new Map();

	public static function init():Void
	{
		if (started) return;
		started = true;
		loadMapping();
		#if android
		call('initialize', '()Z');
		FlxG.signals.postUpdate.add(poll);
		#end
	}

	public static function loadMapping():Void
	{
		achievementIds.clear();
		leaderboardIds.clear();
		var raw:String = null;
		try
		{
			raw = Paths.getTextFromFile(MAPPING_FILE);
		}
		catch (e:Dynamic) {}
		if (raw == null || raw.trim().length == 0) return;
		try
		{
			var json:Dynamic = haxe.Json.parse(raw);
			readMap(Reflect.field(json, 'achievements'), achievementIds);
			readMap(Reflect.field(json, 'leaderboards'), leaderboardIds);
		}
		catch (e:Dynamic)
		{
			fail('mapping:' + Std.string(e));
		}
	}

	public static function signIn():Void
	{
		#if android
		call('signIn', '()V');
		#end
	}

	public static function unlockAchievement(name:String):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null) return false;
		if (!signedIn)
		{
			if (!pendingAchievements.contains(id)) pendingAchievements.push(id);
			return false;
		}
		#if android
		return call('unlockAchievement', '(Ljava/lang/String;)Z', [id]) == true;
		#else
		return false;
		#end
	}

	public static function incrementAchievement(name:String, steps:Int = 1):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null || steps <= 0) return false;
		#if android
		return call('incrementAchievement', '(Ljava/lang/String;I)Z', [id, steps]) == true;
		#else
		return false;
		#end
	}

	public static function setAchievementSteps(name:String, steps:Int):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null || steps <= 0) return false;
		#if android
		return call('setAchievementSteps', '(Ljava/lang/String;I)Z', [id, steps]) == true;
		#else
		return false;
		#end
	}

	public static function revealAchievement(name:String):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null) return false;
		#if android
		return call('revealAchievement', '(Ljava/lang/String;)Z', [id]) == true;
		#else
		return false;
		#end
	}

	public static function submitScore(leaderboard:String, score:Float):Bool
	{
		var id:String = resolveLeaderboard(leaderboard);
		if (id == null || score < 0) return false;
		#if android
		return call('submitScore', '(Ljava/lang/String;D)Z', [id, Math.ffloor(score)]) == true;
		#else
		return false;
		#end
	}

	public static function submitSongScore(song:String, difficulty:String, score:Int):Bool
	{
		if (song == null) return false;
		var base:String = Paths.formatToSongPath(song);
		var diff:String = difficulty == null ? '' : Paths.formatToSongPath(difficulty);
		var keys:Array<String> = diff.length > 0 ? ['$base-$diff', base] : [base];
		for (key in keys)
			if (leaderboardIds.exists(key)) return submitScore(key, score);
		return false;
	}

	public static function showAchievements():Bool
	{
		#if android
		if (!signedIn)
		{
			signIn();
			return false;
		}
		return call('showAchievements', '()Z') == true;
		#else
		return false;
		#end
	}

	public static function showLeaderboard(?leaderboard:String):Bool
	{
		#if android
		if (!signedIn)
		{
			signIn();
			return false;
		}
		var id:String = leaderboard == null ? '' : resolveLeaderboard(leaderboard);
		return call('showLeaderboard', '(Ljava/lang/String;)Z', [id == null ? '' : id]) == true;
		#else
		return false;
		#end
	}

	public static function hasAchievement(name:String):Bool
		return resolveAchievement(name) != null;

	public static function hasLeaderboard(name:String):Bool
		return resolveLeaderboard(name) != null;

	static function resolveAchievement(name:String):String
	{
		if (name == null || name.length == 0) return null;
		if (achievementIds.exists(name)) return achievementIds.get(name);
		return looksLikeId(name) ? name : null;
	}

	static function resolveLeaderboard(name:String):String
	{
		if (name == null || name.length == 0) return null;
		if (leaderboardIds.exists(name)) return leaderboardIds.get(name);
		return looksLikeId(name) ? name : null;
	}

	static inline function looksLikeId(value:String):Bool
		return StringTools.startsWith(value, 'Cg');

	static function readMap(source:Dynamic, target:Map<String, String>):Void
	{
		if (source == null) return;
		for (field in Reflect.fields(source))
		{
			var value:Dynamic = Reflect.field(source, field);
			if (value != null && Std.string(value).length > 0) target.set(field, Std.string(value));
		}
	}

	static function poll():Void
	{
		#if android
		var guard:Int = 0;
		while (guard++ < 16)
		{
			var raw:Dynamic = call('pollEvent', '()Ljava/lang/String;');
			if (raw == null) return;
			var text:String = Std.string(raw);
			if (text.length == 0) return;
			var split:Int = text.indexOf('\n');
			var type:String = split < 0 ? text : text.substr(0, split);
			var data:String = split < 0 ? '' : text.substr(split + 1);
			switch (type)
			{
				case 'signin':
					var parts:Array<String> = data.split('\t');
					player = {id: parts[0], name: parts.length > 1 ? parts[1] : ''};
					flushPending();
					onSignIn.dispatch(player);
				case 'signout':
					player = null;
					onSignOut.dispatch();
				case 'error':
					fail(data);
			}
		}
		#end
	}

	static function flushPending():Void
	{
		var list:Array<String> = pendingAchievements;
		pendingAchievements = [];
		for (id in list) unlockAchievement(id);
		#if ACHIEVEMENTS_ALLOWED
		for (name in funkin.data.achievements.Achievements.achievementsUnlocked)
			if (achievementIds.exists(name)) unlockAchievement(name);
		#end
	}

	static function fail(message:String):Void
	{
		lastError = message;
		onError.dispatch(message);
	}

	#if android
	static function call(name:String, signature:String, ?args:Array<Dynamic>):Dynamic
	{
		try
		{
			var key:String = name + signature;
			var method:Dynamic = methods.get(key);
			if (method == null)
			{
				method = JNI.createStaticMethod(CLASS, name, signature);
				methods.set(key, method);
			}
			if (method == null) return null;
			return Reflect.callMethod(null, method, args == null ? [] : args);
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
			return null;
		}
	}
	#end

	static function get_supported():Bool
	{
		#if android
		return true;
		#else
		return false;
		#end
	}

	static function get_configured():Bool
	{
		#if android
		return call('isConfigured', '()Z') == true;
		#else
		return false;
		#end
	}

	static function get_signedIn():Bool
	{
		#if android
		return player != null && call('isAuthenticated', '()Z') == true;
		#else
		return false;
		#end
	}

	static function get_busy():Bool
	{
		#if android
		return call('isBusy', '()Z') == true;
		#else
		return false;
		#end
	}
}
