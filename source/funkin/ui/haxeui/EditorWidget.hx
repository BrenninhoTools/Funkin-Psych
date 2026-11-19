package funkin.ui.haxeui;

import haxe.ui.core.Component;
import haxe.ui.events.UIEvent;

class EditorWidget<T:Component> extends FlxSpriteGroup
{
	public var name:String;
	public var component(default, null):T;
	public var broadcastEvents:Bool = true;

	var silent:Bool = false;

	public function new(x:Float, y:Float, component:T)
	{
		super(x, y);
		this.component = component;
		EditorUI.bind(component, this);
		add(component);
	}

	override function update(elapsed:Float)
	{
		if (visible && active) EditorUI.touch(component);
		super.update(elapsed);
	}

	inline function quietly(action:Void->Void)
	{
		var previous:Bool = silent;
		silent = true;
		action();
		silent = previous;
	}

	function broadcast(id:String)
	{
		if (broadcastEvents) funkin.ui.psych.PsychUIEventHandler.event(id, this);
	}

	public function resize(width:Float, height:Float)
	{
		if (width > 0) component.width = width;
		if (height > 0) component.height = height;
	}

	public function style():EditorTextStyle
		return new EditorTextStyle(component);

	override function destroy()
	{
		EditorUI.release(component);
		super.destroy();
	}
}

class EditorTextStyle
{
	var target:Component;

	public function new(target:Component)
		this.target = target;

	public var text(get, set):String;
	function get_text():String
		return target.text;

	function set_text(value:String):String
	{
		target.text = value;
		return value;
	}

	public var alignment(never, set):flixel.text.FlxText.FlxTextAlign;
	function set_alignment(value:flixel.text.FlxText.FlxTextAlign):flixel.text.FlxText.FlxTextAlign
	{
		target.customStyle.textAlign = Std.string(value).toLowerCase();
		target.invalidateComponentStyle();
		return value;
	}

	public var size(never, set):Int;
	function set_size(value:Int):Int
	{
		target.customStyle.fontSize = value;
		target.invalidateComponentStyle();
		return value;
	}

	public var color(never, set):FlxColor;
	function set_color(value:FlxColor):FlxColor
	{
		target.customStyle.color = value.rgb;
		target.invalidateComponentStyle();
		return value;
	}
}

class EditorButtonStyle
{
	var target:Component;

	public function new(target:Component)
		this.target = target;

	public var bgColor(never, set):FlxColor;
	function set_bgColor(value:FlxColor):FlxColor
	{
		target.customStyle.backgroundColor = value.rgb;
		target.customStyle.backgroundColorEnd = value.rgb;
		target.invalidateComponentStyle();
		return value;
	}

	public var textColor(never, set):FlxColor;
	function set_textColor(value:FlxColor):FlxColor
	{
		target.customStyle.color = value.rgb;
		target.invalidateComponentStyle();
		return value;
	}

	public var bgAlpha(never, set):Float;
	function set_bgAlpha(value:Float):Float
	{
		target.customStyle.backgroundOpacity = value;
		target.invalidateComponentStyle();
		return value;
	}
}
