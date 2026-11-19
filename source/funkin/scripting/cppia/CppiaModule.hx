package funkin.scripting.cppia;

#if CPPIA_ALLOWED
import cpp.cppia.Module;

@:headerInclude('hx/Scriptable.h')
@:cppInclude('hx/Scriptable.h')
class CppiaModule
{
	public var path(default, null):String;
	public var name(default, null):String;
	public var module(default, null):Module;
	public var instances(default, null):Array<Dynamic> = [];
	public var active:Bool = true;
	public var booted(default, null):Bool = false;

	public function new(path:String, module:Module)
	{
		this.path = path;
		this.module = module;
		this.name = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(path));
	}

	public function boot()
	{
		if (booted) return;
		module.boot();
		booted = true;
	}

	public function run()
	{
		boot();
		module.run();
	}

	public function resolveClass(className:String):Class<Dynamic>
	{
		if (className == null || className.length == 0) return null;
		try
		{
			return module.resolveClass(className);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public function createInstance(className:String, ?args:Array<Dynamic>):Dynamic
	{
		var cls:Class<Dynamic> = resolveClass(className);
		if (cls == null) return null;
		var instance:Dynamic = Type.createInstance(cls, args != null ? args : []);
		if (instance != null) instances.push(instance);
		return instance;
	}

	public function addInstance(instance:Dynamic)
	{
		if (instance != null && !instances.contains(instance)) instances.push(instance);
	}

	public function exists(field:String):Bool
	{
		for (instance in instances)
			if (Reflect.isFunction(Reflect.getProperty(instance, field))) return true;
		return false;
	}

	public function call(field:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active) return null;
		var result:Dynamic = null;
		for (instance in instances)
		{
			var func:Dynamic = Reflect.getProperty(instance, field);
			if (!Reflect.isFunction(func)) continue;
			try
			{
				var value:Dynamic = Reflect.callMethod(instance, func, args != null ? args : []);
				if (value != null) result = value;
			}
			catch (e:Dynamic)
			{
				CppiaHandler.reportError(this, field, e);
			}
		}
		return result;
	}

	public function set(field:String, value:Dynamic)
	{
		for (instance in instances)
		{
			try
			{
				Reflect.setProperty(instance, field, value);
			}
			catch (e:Dynamic) {}
		}
	}

	public function destroy()
	{
		active = false;
		instances = [];
	}
}
#end
