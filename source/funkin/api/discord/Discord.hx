package funkin.api.discord;

#if DISCORD_ALLOWED
import flixel.util.FlxSignal.FlxTypedSignal;
import lime.app.Application;

enum abstract DiscordStatus(Int) from Int to Int
{
	var UNSUPPORTED = -1;
	var DISCONNECTED = 0;
	var CONNECTING = 1;
	var CONNECTED = 2;
}

enum abstract DiscordActivityType(Int) from Int to Int
{
	var PLAYING = 0;
	var LISTENING = 2;
	var WATCHING = 3;
	var COMPETING = 5;
}

typedef DiscordUserData =
{
	var id:String;
	var username:String;
	var globalName:String;
	var avatar:String;
}

typedef DiscordButtonData =
{
	var label:String;
	var url:String;
}

#if cpp
@:include('funkin_discord.h')
extern class DiscordNative
{
	@:native('::funkin_discord::supported') static function supported():Bool;
	@:native('::funkin_discord::start') static function start(clientId:cpp.ConstCharStar):Void;
	@:native('::funkin_discord::stop') static function stop():Void;
	@:native('::funkin_discord::status') static function status():Int;
	@:native('::funkin_discord::pollEvent') static function pollEvent():Int;
	@:native('::funkin_discord::setActivity') static function setActivity(type:Int, details:cpp.ConstCharStar, state:cpp.ConstCharStar,
		largeImage:cpp.ConstCharStar, largeText:cpp.ConstCharStar, smallImage:cpp.ConstCharStar, smallText:cpp.ConstCharStar, start:Float,
		end:Float):Void;
	@:native('::funkin_discord::setParty') static function setParty(id:cpp.ConstCharStar, size:Int, max:Int):Void;
	@:native('::funkin_discord::setButton') static function setButton(index:Int, label:cpp.ConstCharStar, url:cpp.ConstCharStar):Void;
	@:native('::funkin_discord::clearButtons') static function clearButtons():Void;
	@:native('::funkin_discord::commit') static function commit():Void;
	@:native('::funkin_discord::clearActivity') static function clearActivity():Void;
	@:native('::funkin_discord::lastErrorCode') static function lastErrorCode():Int;
}

@:build(funkin.util.macro.NativeLibrary.build('discordrpc'))
#end
class DiscordClient
{
	static inline final EVENT_READY:Int = 1;
	static inline final EVENT_DISCONNECTED:Int = 2;
	static inline final EVENT_ERROR:Int = 3;

	public static var isInitialized:Bool = false;
	private inline static final _defaultID:String = "863222024192262205";
	public static var clientID(default, set):String = _defaultID;

	public static var supported(get, never):Bool;
	public static var status(get, never):DiscordStatus;
	public static var connected(get, never):Bool;
	public static var platform(get, never):String;
	public static var user(default, null):DiscordUserData = null;
	public static var lastError(default, null):String = '';
	public static var lastErrorCode(default, null):Int = 0;

	public static final onReady:FlxTypedSignal<DiscordUserData->Void> = new FlxTypedSignal<DiscordUserData->Void>();
	public static final onDisconnected:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
	public static final onError:FlxTypedSignal<(Int, String)->Void> = new FlxTypedSignal<(Int, String)->Void>();

	public static var activityType:DiscordActivityType = PLAYING;
	public static var details:String = 'In the Menus';
	public static var state:String = null;
	public static var largeImageKey:String = 'icon';
	public static var largeImageText:String = null;
	public static var smallImageKey:String = null;
	public static var smallImageText:String = null;
	public static var startTimestamp:Float = 0;
	public static var endTimestamp:Float = 0;
	public static var partyId:String = null;
	public static var partySize:Int = 0;
	public static var partyMax:Int = 0;
	public static var buttons:Array<DiscordButtonData> = [];

	static var hooked:Bool = false;
	static var closeHooked:Bool = false;

	public static function check()
	{
		if (Save.data.discordRPC) initialize();
		else if (isInitialized) shutdown();
	}

	public static function prepare()
	{
		if (!isInitialized && Save.data.discordRPC) initialize();

		if (!closeHooked && Application.current != null && Application.current.window != null)
		{
			closeHooked = true;
			Application.current.window.onClose.add(function() {
				if (isInitialized) shutdown();
			});
		}
	}

	public dynamic static function shutdown()
	{
		isInitialized = false;
		user = null;
		#if cpp
		DiscordNative.stop();
		#end
	}

	public static function initialize()
	{
		#if cpp
		if (!DiscordNative.supported()) return;
		DiscordNative.start(str(clientID));
		#end
		if (!hooked)
		{
			hooked = true;
			FlxG.signals.postUpdate.add(pollEvents);
		}
		isInitialized = true;
		updatePresence();
	}

	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool,
			?endTimestamp:Float, largeImageKey:String = 'icon')
	{
		var start:Float = hasStartTimestamp ? Date.now().getTime() : 0;
		var end:Float = endTimestamp != null && endTimestamp > 0 ? (hasStartTimestamp ? start : Date.now().getTime()) + endTimestamp : 0;

		DiscordClient.details = details;
		DiscordClient.state = state;
		DiscordClient.smallImageKey = smallImageKey;
		DiscordClient.largeImageKey = largeImageKey;
		DiscordClient.largeImageText = "Engine Version: " + funkin.ui.mainmenu.MainMenuState.psychEngineVersion;
		DiscordClient.startTimestamp = Math.ffloor(start / 1000);
		DiscordClient.endTimestamp = Math.ffloor(end / 1000);
		updatePresence();
	}

	public static function setButtons(?list:Array<DiscordButtonData>)
	{
		buttons = list != null ? list.slice(0, 2) : [];
		updatePresence();
	}

	public static function setParty(?id:String, size:Int = 0, max:Int = 0)
	{
		partyId = id;
		partySize = size;
		partyMax = max;
		updatePresence();
	}

	public static function clearPresence()
	{
		#if cpp
		if (isInitialized) DiscordNative.clearActivity();
		#end
	}

	public static function updatePresence()
	{
		#if cpp
		if (!isInitialized) return;
		DiscordNative.setActivity(activityType, str(details), str(state), str(largeImageKey), str(largeImageText), str(smallImageKey),
			str(smallImageText), startTimestamp, endTimestamp);
		DiscordNative.setParty(str(partyId), partySize, partyMax);
		DiscordNative.clearButtons();
		for (i in 0...Std.int(Math.min(buttons.length, 2)))
		{
			var button:DiscordButtonData = buttons[i];
			if (button != null) DiscordNative.setButton(i, str(button.label), str(button.url));
		}
		DiscordNative.commit();
		#end
	}

	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	private static function set_clientID(newID:String)
	{
		if (newID == null || newID.length == 0) newID = _defaultID;
		var change:Bool = (clientID != newID);
		clientID = newID;

		if (change && isInitialized)
		{
			shutdown();
			initialize();
		}
		return newID;
	}

	static function pollEvents()
	{
		#if cpp
		if (!isInitialized) return;
		var event:Int = DiscordNative.pollEvent();
		while (event != 0)
		{
			switch (event)
			{
				case EVENT_READY:
					user = {
						id: nativeUserId(),
						username: nativeUserName(),
						globalName: nativeGlobalName(),
						avatar: nativeAvatar()
					};
					onReady.dispatch(user);
				case EVENT_DISCONNECTED:
					user = null;
					onDisconnected.dispatch();
				case EVENT_ERROR:
					lastError = nativeLastError();
					lastErrorCode = DiscordNative.lastErrorCode();
					onError.dispatch(lastErrorCode, lastError);
			}
			event = DiscordNative.pollEvent();
		}
		#end
	}

	static function get_supported():Bool
	{
		#if cpp
		return DiscordNative.supported();
		#else
		return false;
		#end
	}

	static function get_status():DiscordStatus
	{
		#if cpp
		return DiscordNative.status();
		#else
		return UNSUPPORTED;
		#end
	}

	static function get_platform():String
	{
		#if cpp
		return nativePlatform();
		#else
		return 'none';
		#end
	}

	static function get_connected():Bool
	{
		return status == CONNECTED;
	}

	#if cpp
	static inline function str(value:String):cpp.ConstCharStar
	{
		return untyped __cpp__('({0}.__s ? {0}.utf8_str() : (const char *)0)', value);
	}

	static function nativeUserId():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::userId())');
	}

	static function nativeUserName():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::userName())');
	}

	static function nativeGlobalName():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::globalName())');
	}

	static function nativeAvatar():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::avatar())');
	}

	static function nativePlatform():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::platformName())');
	}

	static function nativeLastError():String
	{
		return untyped __cpp__('::String::create(::funkin_discord::lastError())');
	}
	#end

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		var pack:Dynamic = Mods.getPack();
		if (pack != null && pack.discordRPC != null && pack.discordRPC != clientID) clientID = pack.discordRPC;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "changeDiscordPresence", changePresence);
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if (newID == null) newID = _defaultID;
			clientID = newID;
		});
		Lua_helper.add_callback(lua, "setDiscordButtons", function(?label1:String, ?url1:String, ?label2:String, ?url2:String) {
			var list:Array<DiscordButtonData> = [];
			if (label1 != null && url1 != null) list.push({label: label1, url: url1});
			if (label2 != null && url2 != null) list.push({label: label2, url: url2});
			setButtons(list);
		});
		Lua_helper.add_callback(lua, "setDiscordParty", function(?id:String, size:Int = 0, max:Int = 0) {
			setParty(id, size, max);
		});
		Lua_helper.add_callback(lua, "clearDiscordPresence", clearPresence);
		Lua_helper.add_callback(lua, "isDiscordConnected", function() return connected);
	}
	#end
}
#end
