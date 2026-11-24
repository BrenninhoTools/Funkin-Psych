package funkin.api.discord;

#if DISCORD_ALLOWED
import flixel.util.FlxSignal.FlxTypedSignal;
import lime.app.Application;
import hxdiscord_rpc.DiscordEvents.DiscordEvents as RpcEvents;
import hxdiscord_rpc.DiscordEvents.DiscordPresence as RpcPresence;

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

class DiscordClient
{
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
	static var presence:RpcPresence = new RpcPresence();

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
		RpcEvents.shutdown();
	}

	public static function initialize()
	{
		if (!RpcEvents.init(clientID)) return;
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
		if (isInitialized) RpcEvents.clearPresence();
	}

	public static function updatePresence()
	{
		if (!isInitialized) return;
		presence.type = activityType;
		presence.details = clip(details);
		presence.state = clip(state);
		presence.largeImageKey = largeImageKey;
		presence.largeImageText = clip(largeImageText);
		presence.smallImageKey = smallImageKey;
		presence.smallImageText = clip(smallImageText);
		presence.startTimestamp = startTimestamp;
		presence.endTimestamp = endTimestamp;
		presence.partyId = partyId;
		presence.partySize = partySize;
		presence.partyMax = partyMax;
		var first:DiscordButtonData = buttons.length > 0 ? buttons[0] : null;
		var second:DiscordButtonData = buttons.length > 1 ? buttons[1] : null;
		presence.button1Label = first != null ? first.label : null;
		presence.button1Url = first != null ? first.url : null;
		presence.button2Label = second != null ? second.label : null;
		presence.button2Url = second != null ? second.url : null;
		RpcEvents.updatePresence(presence);
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
		if (!isInitialized) return;
		RpcEvents.update();
		RpcEvents.pollAll(function(event) {
			switch (event)
			{
				case Ready(data):
					user = {
						id: data.userId,
						username: data.username,
						globalName: data.globalName,
						avatar: data.avatar
					};
					updatePresence();
					onReady.dispatch(user);
				case Disconnected(code, message):
					user = null;
					lastErrorCode = code;
					lastError = message;
					onDisconnected.dispatch();
				case Errored(code, message):
					lastErrorCode = code;
					lastError = message;
					onError.dispatch(code, message);
				default:
			}
		});
	}

	static function clip(value:String):String
	{
		if (value == null || value.length <= 128) return value;
		return value.substr(0, 125) + '...';
	}

	static function get_supported():Bool
	{
		return RpcEvents.supported;
	}

	static function get_status():DiscordStatus
	{
		if (!RpcEvents.supported) return UNSUPPORTED;
		if (!isInitialized) return DISCONNECTED;
		return RpcEvents.ready ? CONNECTED : CONNECTING;
	}

	static function get_connected():Bool
	{
		return status == CONNECTED;
	}

	static function get_platform():String
	{
		#if windows
		return 'windows';
		#elseif mac
		return 'macos';
		#elseif linux
		return 'linux';
		#elseif android
		return 'android';
		#elseif ios
		return 'ios';
		#else
		return 'unknown';
		#end
	}

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
