package funkin.switchgame;

import funkin.data.DataUtil;
import funkin.data.ui.UIData;
import haxe.io.Path;

typedef EngineLaunch =
{
	@:optional var path:String;
	@:optional var packageName:String;
	@:optional var url:String;
	@:optional var workingDirectory:String;
	@:optional var args:Array<String>;
}

typedef SwitchEngine =
{
	var id:String;
	var name:String;
	var description:String;
	var color:String;
	var args:Array<String>;
	var launch:Dynamic;
}

#if cpp
@:build(funkin.util.macro.NativeLibrary.build('switchgame'))
#end
class SwitchGame
{
	public static inline final FOLDER:String = 'switchgame';
	public static inline final FILE:String = 'engines';
	public static inline final FROM_ARGUMENT:String = '--switchgame-from=';

	public static var selfId(default, null):String = 'funkin-psych';
	public static var engines(default, null):Array<SwitchEngine> = [];
	public static var lastError(default, null):String = '';
	public static var launchedFrom(get, never):String;
	public static var exitDelay:Float = 0.35;

	static var launchedFromCache:String = null;
	static var parsedArguments:Bool = false;
	static var introPlayed:Bool = false;

	public static function version():String
	{
		#if cpp
		return SwitchGameNative.version().toString();
		#else
		return 'unavailable';
		#end
	}

	public static function platform():String
	{
		#if cpp
		return SwitchGameNative.platform().toString();
		#elseif android
		return 'android';
		#elseif ios
		return 'ios';
		#elseif windows
		return 'windows';
		#elseif mac
		return 'mac';
		#elseif linux
		return 'linux';
		#else
		return 'web';
		#end
	}

	public static function load():Array<SwitchEngine>
	{
		UIData.clearFileCache();
		var raw:Dynamic = UIData.readFile(FOLDER, FILE);
		engines = [];
		if (raw == null) return engines;
		if (raw.self != null) selfId = Std.string(raw.self);
		var list:Array<Dynamic> = raw.engines != null ? raw.engines : [];
		for (entry in list)
		{
			if (entry == null || entry.id == null) continue;
			var id:String = Std.string(entry.id);
			if (id == selfId || entry.hidden == true) continue;
			engines.push({
				id: id,
				name: entry.name != null ? Std.string(entry.name) : id,
				description: entry.description != null ? Std.string(entry.description) : '',
				color: entry.color != null ? Std.string(entry.color) : '#FFFFFF',
				args: stringList(entry.args),
				launch: entry.launch != null ? entry.launch : {}
			});
		}
		return engines;
	}

	public static function find(id:String):SwitchEngine
	{
		if (engines.length < 1) load();
		for (engine in engines) if (engine.id == id) return engine;
		return null;
	}

	public static function describe(id:String):{name:String, color:String}
	{
		var raw:Dynamic = UIData.readFile(FOLDER, FILE);
		var list:Array<Dynamic> = raw != null && raw.engines != null ? raw.engines : [];
		for (entry in list)
			if (entry != null && Std.string(entry.id) == id)
				return {name: entry.name != null ? Std.string(entry.name) : id, color: entry.color != null ? Std.string(entry.color) : '#FFFFFF'};
		return {name: id, color: '#FFFFFF'};
	}

	public static function playIntro():Bool
	{
		var from:String = launchedFrom;
		if (from == null || from.length < 1 || introPlayed) return false;
		introPlayed = true;
		var source = describe(from);
		var self = describe(selfId);
		funkin.ui.switchgame.SwitchTransition.playIn(source.name, UIData.parseColor(source.color, FlxColor.WHITE), self.name, UIData.parseColor(self.color, FlxColor.WHITE));
		return true;
	}

	public static function launchFor(engine:SwitchEngine):EngineLaunch
	{
		if (engine == null || engine.launch == null) return null;
		var info:Dynamic = Reflect.field(engine.launch, platform());
		if (info == null) return null;
		if (Std.isOfType(info, String))
		{
			var text:String = info;
			return switch (platform())
			{
				case 'android': {packageName: text};
				case 'ios': {url: text};
				default: text.indexOf('://') > 0 ? {url: text} : {path: text};
			}
		}
		return {
			path: info.path != null ? Std.string(info.path) : null,
			packageName: DataUtil.field(info, ['package', 'packageName']) != null ? Std.string(DataUtil.field(info, ['package', 'packageName'])) : null,
			url: info.url != null ? Std.string(info.url) : null,
			workingDirectory: info.workingDirectory != null ? Std.string(info.workingDirectory) : null,
			args: stringList(info.args)
		};
	}

	public static function isAvailable(engine:SwitchEngine):Bool
	{
		var launch:EngineLaunch = launchFor(engine);
		if (launch == null) return false;
		#if cpp
		if (launch.packageName != null) return SwitchGameNative.packageInstalled(native(launch.packageName));
		if (launch.path != null) return SwitchGameNative.pathExists(native(resolvePath(launch.path)));
		if (launch.url != null) return SwitchGameNative.urlAvailable(native(launch.url));
		#end
		return false;
	}

	public static function supported(engine:SwitchEngine):Bool
		return launchFor(engine) != null;

	public static function switchTo(engine:SwitchEngine, exitAfter:Bool = true, ?delay:Float):Bool
	{
		lastError = '';
		var launch:EngineLaunch = launchFor(engine);
		if (launch == null)
		{
			lastError = 'Engine has no launch info for ${platform()}';
			return false;
		}

		var args:Array<String> = engine.args.concat(launch.args != null ? launch.args : []);
		args.push(FROM_ARGUMENT + selfId);
		var started:Bool = false;
		#if cpp
		var joined:String = args.join('\n');
		if (launch.packageName != null)
			started = SwitchGameNative.launchPackage(native(launch.packageName), native(joined));
		else if (launch.path != null)
		{
			var path:String = resolvePath(launch.path);
			var directory:String = launch.workingDirectory != null ? resolvePath(launch.workingDirectory) : Path.directory(path);
			started = SwitchGameNative.launchExecutable(native(path), native(joined), native(directory));
		}
		else if (launch.url != null)
			started = SwitchGameNative.launchUrl(native(launch.url));
		if (!started) lastError = SwitchGameNative.lastError().toString();
		#else
		if (launch.url != null)
		{
			CoolUtil.browserLoad(launch.url);
			started = true;
		}
		else lastError = 'SwitchGame needs a native target';
		#end

		if (started && exitAfter)
		{
			Save.saveSettings();
			new FlxTimer().start(delay != null ? delay : exitDelay, (_) -> lime.system.System.exit(0));
		}
		return started;
	}

	public static function gameDirectory():String
	{
		#if sys
		var program:String = Path.directory(Sys.programPath());
		#if mac
		var marker:Int = program.indexOf('.app/');
		if (marker > -1) program = Path.directory(program.substr(0, marker + 4));
		#end
		return Path.normalize(program);
		#else
		return '';
		#end
	}

	public static function resolvePath(path:String):String
	{
		if (path == null) return null;
		var home:String = #if sys Sys.getEnv(#if windows 'USERPROFILE' #else 'HOME' #end) #else null #end;
		var result:String = path.split('{gameDir}').join(gameDirectory()).split('{home}').join(home != null ? home : '');
		if (result.startsWith('~/') && home != null) result = home + result.substr(1);
		if (!Path.isAbsolute(result)) result = Path.join([gameDirectory(), result]);
		return Path.normalize(result);
	}

	#if cpp
	static function native(value:String):cpp.ConstCharStar
	{
		var text:String = value != null ? value : '';
		return cpp.ConstCharStar.fromString(text);
	}
	#end

	static function stringList(value:Dynamic):Array<String>
	{
		if (value == null) return [];
		var list:Array<Dynamic> = Std.isOfType(value, Array) ? value : [value];
		return [for (entry in list) Std.string(entry)];
	}

	static function get_launchedFrom():String
	{
		if (parsedArguments) return launchedFromCache;
		parsedArguments = true;
		var arguments:Array<String> = [];
		#if sys
		arguments = arguments.concat(Sys.args());
		#end
		#if cpp
		var extra:String = SwitchGameNative.launchArguments().toString();
		if (extra != null && extra.length > 0) arguments = arguments.concat(extra.split('\n'));
		#end
		for (argument in arguments)
			if (argument.startsWith(FROM_ARGUMENT)) launchedFromCache = argument.substr(FROM_ARGUMENT.length);
		return launchedFromCache;
	}
}
