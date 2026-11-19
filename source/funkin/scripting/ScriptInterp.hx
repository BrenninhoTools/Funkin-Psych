package funkin.scripting;

#if HSCRIPT_ALLOWED
import hscript.Expr;
import hscript.Interp;
import hscript.Tools;

class ScriptInterp extends Interp
{
	public static inline final IMPORT_FUNCTION:String = "__import__";
	public static inline final USING_FUNCTION:String = "__using__";
	public static inline final STRING_FUNCTION:String = "__string__";
	public static inline final GLOBAL_META:String = "__global__";

	public var imports:Map<String, Dynamic> = new Map();
	public var usings:Array<Dynamic> = [];
	public var wildcards:Array<String> = [];
	public var parentInstance(default, set):Dynamic = null;
	public var onWarning:String->haxe.PosInfos->Void;

	var parentFields:Map<String, Bool> = new Map();

	public function new()
	{
		super();
		variables.set(IMPORT_FUNCTION, importPath);
		variables.set(USING_FUNCTION, usePath);
		variables.set(STRING_FUNCTION, Std.string);
		for (name => value in ScriptImports.defaults())
			variables.set(name, value);
		usings.push(StringTools);
	}

	function set_parentInstance(instance:Dynamic):Dynamic
	{
		parentInstance = instance;
		parentFields = new Map();
		if (instance != null)
		{
			var cls:Class<Dynamic> = Type.getClass(instance);
			if (cls != null)
				for (field in Type.getInstanceFields(cls))
					parentFields.set(field, true);
		}
		return instance;
	}

	public function hasParentField(name:String):Bool
		return parentInstance != null && parentFields.exists(name);

	public function importPath(path:String, ?alias:String):Dynamic
	{
		if (path == null || path.length == 0) return null;
		if (path.endsWith(".*"))
		{
			var pack:String = path.substr(0, path.length - 2);
			if (!wildcards.contains(pack)) wildcards.push(pack);
			return null;
		}

		if (ScriptImports.isBlocked(path))
		{
			warn('Import of $path is not allowed');
			return null;
		}
		var value:Dynamic = ScriptImports.resolve(path);
		if (value == null)
		{
			warn('Import of $path could not be added');
			return null;
		}

		var name:String = alias != null ? alias : path.substr(path.lastIndexOf(".") + 1);
		imports.set(name, value);
		if (alias != null) imports.set(path.substr(path.lastIndexOf(".") + 1), value);
		return value;
	}

	public function usePath(path:String, ?alias:String):Dynamic
	{
		var value:Dynamic = ScriptImports.resolve(path);
		if (value == null)
		{
			warn('Using of $path could not be added');
			return null;
		}
		if (!usings.contains(value)) usings.insert(0, value);
		return value;
	}

	override function resolve(id:String):Dynamic
	{
		if (variables.exists(id)) return variables.get(id);
		if (imports.exists(id)) return imports.get(id);
		if (hasParentField(id)) return Reflect.getProperty(parentInstance, id);

		for (pack in wildcards)
		{
			var value:Dynamic = ScriptImports.resolve(pack + "." + id);
			if (value != null)
			{
				imports.set(id, value);
				return value;
			}
		}

		var value:Dynamic = ScriptImports.resolve(id);
		if (value != null)
		{
			imports.set(id, value);
			return value;
		}

		if (ScriptImports.isPackage(id)) return new ScriptPackage(id);

		return error(EUnknownVariable(id));
	}

	override function setVar(name:String, v:Dynamic)
	{
		if (!variables.exists(name) && hasParentField(name))
		{
			Reflect.setProperty(parentInstance, name, v);
			return v;
		}
		variables.set(name, v);
		return v;
	}

	override function exprMeta(meta:String, args:Array<Expr>, e:Expr):Dynamic
	{
		if (meta == GLOBAL_META)
		{
			switch (Tools.expr(e))
			{
				case EVar(name, _, value):
					variables.set(name, value == null ? null : expr(value));
					return null;
				default:
			}
		}
		return expr(e);
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if (Std.isOfType(o, ScriptPackage))
		{
			var path:String = cast(o, ScriptPackage).path + "." + f;
			var value:Dynamic = ScriptImports.resolve(path);
			return value != null ? value : new ScriptPackage(path);
		}
		return super.get(o, f);
	}

	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		var func:Dynamic = Std.isOfType(o, ScriptPackage) ? get(o, f) : Reflect.getProperty(o, f);
		if (func != null && Reflect.isFunction(func))
			return Reflect.callMethod(o, func, args);

		for (target in usings)
		{
			var extension:Dynamic = Reflect.field(target, f);
			if (extension != null && Reflect.isFunction(extension))
				return Reflect.callMethod(target, extension, [o].concat(args));
		}

		return error(ECustom('Tried to call null function $f'));
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic
	{
		var cls:Dynamic = imports.get(cl);
		if (cls == null) cls = ScriptImports.resolve(cl);
		if (cls == null)
			for (pack in wildcards)
			{
				cls = ScriptImports.resolve(pack + "." + cl);
				if (cls != null) break;
			}
		if (cls == null && variables.exists(cl)) cls = variables.get(cl);
		if (cls == null) return error(ECustom('Class not found: $cl'));
		return Type.createInstance(cls, args);
	}

	public function scriptError(message:String):Dynamic
		return error(ECustom(message));

	function warn(message:String)
	{
		if (onWarning != null) onWarning(message, posInfos());
	}
}

class ScriptPackage
{
	public var path(default, null):String;

	public function new(path:String)
		this.path = path;

	public function toString():String
		return path;
}
#end
