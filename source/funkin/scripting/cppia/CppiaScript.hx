package funkin.scripting.cppia;

import flixel.FlxBasic;

class CppiaScript
{
	public var game(get, never):PlayState;
	public var module:Dynamic;

	public function new() {}

	inline function get_game():PlayState
		return PlayState.instance;

	public function add(object:FlxBasic):FlxBasic
		return game != null ? game.add(object) : object;

	public function insert(position:Int, object:FlxBasic):FlxBasic
		return game != null ? game.insert(position, object) : object;

	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic
		return game != null ? game.remove(object, splice) : object;

	public function getVar(name:String):Dynamic
		return game != null ? game.variables.get(name) : null;

	public function setVar(name:String, value:Dynamic):Dynamic
	{
		if (game != null) game.variables.set(name, value);
		return value;
	}
}
