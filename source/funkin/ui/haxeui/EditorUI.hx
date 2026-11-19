package funkin.ui.haxeui;

import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.backend.flixel.StateHelper;
import haxe.ui.focus.FocusManager;

class EditorUI
{
	static var touched:Map<Component, Int> = [];
	static var owners:Map<Component, Dynamic> = [];
	static var tick:Int = 0;
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized) return;
		initialized = true;
		FlxG.signals.preStateSwitch.add(releaseAll);
		FlxG.signals.postUpdate.add(onPostUpdate);
	}

	public static function bind(component:Component, owner:Dynamic)
	{
		init();
		owners.set(component, owner);
	}

	public static function touch(component:Component)
	{
		if (component == null) return;
		init();
		touched.set(component, tick);
		register(component);
	}

	@:access(haxe.ui.backend.ComponentImpl)
	@:access(haxe.ui.core.Screen)
	static function register(component:Component)
	{
		var screen:Screen = Screen.instance;
		if (!screen.rootComponents.contains(component)) screen.rootComponents.push(component);
		var current = StateHelper.currentState;
		if (component.state != current) component.state = current;
		if (!component.isReady)
		{
			component.recursiveReady();
			component.syncComponentValidation();
			component.applyAddInternal();
		}
	}

	@:access(haxe.ui.core.Screen)
	static function unregister(component:Component)
	{
		Screen.instance.rootComponents.remove(component);
		touched.remove(component);
	}

	static function onPostUpdate()
	{
		for (component => last in touched)
			if (last != tick) unregister(component);
		tick++;
	}

	public static function release(component:Component)
	{
		if (component == null) return;
		unregister(component);
		owners.remove(component);
	}

	static function releaseAll()
	{
		for (component in touched.keys()) unregister(component);
		touched.clear();
		owners.clear();
	}

	public static function focusedOwner():Dynamic
	{
		var focus:Dynamic = FocusManager.instance.focus;
		var component:Component = Std.isOfType(focus, Component) ? cast focus : null;
		while (component != null)
		{
			if (owners.exists(component)) return owners.get(component);
			component = component.parentComponent;
		}
		return null;
	}

	public static function clearFocus()
	{
		FocusManager.instance.focus = null;
	}
}
