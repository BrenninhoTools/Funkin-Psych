package funkin.api.playgames;

import flixel.util.FlxSignal.FlxTypedSignal;
#if android
import androidmanager.games.PlayGames as AndroidPlayGames;
#end

typedef PlayGamesPlayer =
{
	var id:String;
	var name:String;
}

class PlayGames
{
	static inline final MAPPING_FILE:String = 'data/playgames.json';

	public static var supported(get, never):Bool;
	public static var configured(get, never):Bool;
	public static var signedIn(get, never):Bool;
	public static var player(get, never):PlayGamesPlayer;
	public static var lastError(default, null):String = '';

	public static final onSignIn:FlxTypedSignal<PlayGamesPlayer->Void> = new FlxTypedSignal<PlayGamesPlayer->Void>();
	public static final onSignOut:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
	public static final onError:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	static var achievementIds:Map<String, String> = new Map();
	static var leaderboardIds:Map<String, String> = new Map();
	static var pendingAchievements:Array<String> = [];
	static var started:Bool = false;

	public static function init():Void
	{
		if (started) return;
		started = true;
		loadMapping();
		#if android
		if (!AndroidPlayGames.available) return;
		AndroidPlayGames.onSignInChanged.add(function(value:Bool) {
			if (value) handleSignIn();
			else onSignOut.dispatch();
		});
		AndroidPlayGames.onStateChange.add(function(_, error) {
			if (error != null) fail(error.code + ': ' + error.message);
		});
		AndroidPlayGames.init(function(ok:Bool) {
			if (ok) handleSignIn();
		});
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
			fail('mapping: ' + Std.string(e));
		}
	}

	public static function signIn():Void
	{
		#if android
		AndroidPlayGames.connect(function(ok:Bool, ?error) {
			if (ok) handleSignIn();
			else if (error != null) fail(error.code + ': ' + error.message);
		});
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
		AndroidPlayGames.unlockAchievement(id);
		return true;
		#else
		return false;
		#end
	}

	public static function incrementAchievement(name:String, steps:Int = 1):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null || steps <= 0 || !signedIn) return false;
		#if android
		AndroidPlayGames.incrementAchievement(id, steps);
		return true;
		#else
		return false;
		#end
	}

	public static function setAchievementSteps(name:String, steps:Int):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null || steps <= 0 || !signedIn) return false;
		#if android
		AndroidPlayGames.setAchievementSteps(id, steps);
		return true;
		#else
		return false;
		#end
	}

	public static function revealAchievement(name:String):Bool
	{
		var id:String = resolveAchievement(name);
		if (id == null || !signedIn) return false;
		#if android
		AndroidPlayGames.revealAchievement(id);
		return true;
		#else
		return false;
		#end
	}

	public static function submitScore(leaderboard:String, score:Float, ?tag:String):Bool
	{
		var id:String = resolveLeaderboard(leaderboard);
		if (id == null || score < 0 || !signedIn) return false;
		#if android
		AndroidPlayGames.submitScore(id, Math.ffloor(score), tag);
		return true;
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
			if (leaderboardIds.exists(key)) return submitScore(key, score, diff);
		return false;
	}

	public static function showAchievements():Bool
	{
		#if android
		if (!configured) return false;
		if (!signedIn)
		{
			signIn();
			return false;
		}
		AndroidPlayGames.showAchievements();
		return true;
		#else
		return false;
		#end
	}

	public static function showLeaderboard(?leaderboard:String):Bool
	{
		#if android
		if (!configured) return false;
		if (!signedIn)
		{
			signIn();
			return false;
		}
		var id:String = leaderboard == null ? null : resolveLeaderboard(leaderboard);
		if (id == null) AndroidPlayGames.showAllLeaderboards();
		else AndroidPlayGames.showLeaderboard(id);
		return true;
		#else
		return false;
		#end
	}

	public static function hasAchievement(name:String):Bool
		return resolveAchievement(name) != null;

	public static function hasLeaderboard(name:String):Bool
		return resolveLeaderboard(name) != null;

	static function handleSignIn():Void
	{
		#if android
		AndroidPlayGames.getCurrentPlayer(function(_, ?_) {
			flushPending();
			onSignIn.dispatch(player);
		});
		#end
	}

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
		return AndroidPlayGames.available;
		#else
		return false;
		#end
	}

	static function get_signedIn():Bool
	{
		#if android
		return AndroidPlayGames.available && AndroidPlayGames.signedIn;
		#else
		return false;
		#end
	}

	static function get_player():PlayGamesPlayer
	{
		#if android
		var current = AndroidPlayGames.player;
		return current == null ? null : {id: current.id, name: current.displayName};
		#else
		return null;
		#end
	}
}
