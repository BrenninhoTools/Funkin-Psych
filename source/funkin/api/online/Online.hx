package funkin.api.online;

#if ONLINE_ALLOWED
import network.Client;
import network.Http;
import network.Types;

class Online
{
	public static var defaultServer:String = 'ws://localhost:7777/';
	public static var client(get, never):Client;
	public static var connected(get, never):Bool;

	static var _client:Client;
	static var hooked:Bool = false;

	public static function connect(?url:String, ?name:String):Client
	{
		var target:String = url != null && url.length > 0 ? url : defaultServer;
		var player:String = name != null && name.length > 0 ? name : 'Player';
		client.connect(target, player);
		return client;
	}

	public static function disconnect():Void
	{
		if (_client != null) _client.disconnect();
	}

	static function get_client():Client
	{
		if (_client == null)
		{
			_client = new Client();
			_client.autoReconnect = true;
			bind(_client);
		}
		if (!hooked)
		{
			hooked = true;
			FlxG.signals.postUpdate.add(update);
		}
		return _client;
	}

	static function get_connected():Bool
		return _client != null && _client.connected;

	static function update():Void
	{
		if (_client != null) _client.update();
		Http.update();
	}

	static function call(name:String, ?args:Array<Dynamic>):Void
	{
		if (PlayState.instance != null) PlayState.instance.callOnScripts(name, args != null ? args : []);
	}

	static function playerTable(player:PlayerInfo):Dynamic
		return player != null ? {id: player.id, name: player.name, data: player.data} : null;

	static function bind(c:Client):Void
	{
		c.onConnect = function() call('onOnlineConnect', [c.id, c.name]);
		c.onDisconnect = function(code, reason) call('onOnlineDisconnect', [code, reason]);
		c.onError = function(error) call('onOnlineError', [error.code, error.message]);
		c.onJoin = function(room) call('onOnlineJoin', [room.id, room.name]);
		c.onLeave = function() call('onOnlineLeave');
		c.onPeerJoin = function(player) call('onOnlinePeerJoin', [playerTable(player)]);
		c.onPeerLeave = function(player, reason) call('onOnlinePeerLeave', [playerTable(player), reason]);
		c.onHostChanged = function(id) call('onOnlineHost', [id, id == c.id]);
		c.onState = function(key, value) call('onOnlineState', [key, value]);
		c.onPlayerData = function(player) call('onOnlinePlayerData', [playerTable(player)]);
		c.onChat = function(player, text) call('onOnlineChat', [playerTable(player), text]);
		c.onStart = function(data, localTime) call('onOnlineStart', [data, (localTime - haxe.Timer.stamp() * 1000) / 1000]);
		c.onStop = function(data) call('onOnlineStop', [data]);
		c.onKicked = function(reason) call('onOnlineKicked', [reason]);
		c.onMessage = function(event, from, data) call('onOnlineMessage', [event, from, data]);
	}

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "onlineConnect", function(?url:String, ?name:String) {
			connect(url, name);
			return true;
		});
		Lua_helper.add_callback(lua, "onlineDisconnect", disconnect);
		Lua_helper.add_callback(lua, "onlineConnected", function() return connected);
		Lua_helper.add_callback(lua, "onlineMyId", function() return _client != null ? _client.id : -1);
		Lua_helper.add_callback(lua, "onlineLatency", function() return _client != null ? _client.latency : 0);
		Lua_helper.add_callback(lua, "onlineServerTime", function() return _client != null ? _client.serverTime() : 0);
		Lua_helper.add_callback(lua, "onlineCreateRoom", function(?name:String, maxPlayers:Int = 2, ?password:String, ?meta:Dynamic) {
			client.createRoom({name: name, maxPlayers: maxPlayers, password: password, meta: meta});
		});
		Lua_helper.add_callback(lua, "onlineJoinRoom", function(id:String, ?password:String) client.joinRoom(id, password));
		Lua_helper.add_callback(lua, "onlineQuickJoin", function(?meta:Dynamic, maxPlayers:Int = 2) client.quickJoin(meta, maxPlayers));
		Lua_helper.add_callback(lua, "onlineLeaveRoom", function() if (_client != null) _client.leaveRoom());
		Lua_helper.add_callback(lua, "onlineRoomId", function() return _client != null && _client.room != null ? _client.room.id : null);
		Lua_helper.add_callback(lua, "onlineIsHost", function() return _client != null && _client.isHost);
		Lua_helper.add_callback(lua, "onlinePlayers", function() {
			if (_client == null || _client.room == null) return [];
			return [for (player in _client.room.playerList()) playerTable(player)];
		});
		Lua_helper.add_callback(lua, "onlineSend", function(event:String, ?data:Dynamic, ?target:Int) {
			if (_client == null) return false;
			return target != null ? _client.sendTo(target, event, data) : _client.send(event, data);
		});
		Lua_helper.add_callback(lua, "onlineChat", function(text:String) return _client != null && _client.chat(text));
		Lua_helper.add_callback(lua, "onlineSetState", function(key:String, ?value:Dynamic) return _client != null && _client.setState(key, value));
		Lua_helper.add_callback(lua, "onlineGetState", function(key:String) return _client != null && _client.room != null ? _client.room.getState(key) : null);
		Lua_helper.add_callback(lua, "onlineSetPlayerData", function(data:Dynamic) return _client != null && _client.setPlayerData(data));
		Lua_helper.add_callback(lua, "onlineStart", function(?data:Dynamic, delay:Float = 0) return _client != null && _client.start(data, delay * 1000));
		Lua_helper.add_callback(lua, "onlineStop", function(?data:Dynamic) return _client != null && _client.stop(data));
		Lua_helper.add_callback(lua, "onlineKick", function(id:Int, ?reason:String) return _client != null && _client.kick(id, reason != null ? reason : ''));
		Lua_helper.add_callback(lua, "onlineSubmitScore", function(board:String, score:Float, ?data:Dynamic) {
			if (_client == null) return false;
			_client.submitScore(board, score, data, function(rank, error) call('onOnlineScore', [board, rank, error != null ? error.message : null]));
			return true;
		});
		Lua_helper.add_callback(lua, "onlineGetScores", function(board:String, limit:Int = 10) {
			if (_client == null) return false;
			_client.getScores(board, limit, function(scores, error) call('onOnlineScores', [board, scores, error != null ? error.message : null]));
			return true;
		});
	}
	#end
}
#end
