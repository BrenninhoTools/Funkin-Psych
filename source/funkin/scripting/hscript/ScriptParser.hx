package funkin.scripting.hscript;

#if HSCRIPT_ALLOWED
import hscript.Expr;
import hscript.Parser;
import hscript.Tools;

class ScriptParser extends Parser
{
	static inline final INTERPOLATION_MARK:String = "\x01interp\x01";

	public static var defines(get, never):Map<String, Dynamic>;
	static var _defines:Map<String, Dynamic>;

	public function new()
	{
		super();
		allowTypes = true;
		allowJSON = true;
		allowMetadata = true;
		for (key => value in defines)
			preprocesorValues.set(key, value);
	}

	public function parseScript(code:String, origin:String):Expr
	{
		var parsed:Expr = parseString(code, origin);
		return markGlobals(interpolateAll(parsed, origin));
	}

	override function parseStructure(id:String):Expr
	{
		switch (id)
		{
			case "import":
				return parseImport(false);
			case "using":
				return parseImport(true);
			case "package":
				var tk = token();
				while (tk != TSemicolon && tk != TEof)
					tk = token();
				push(tk);
				return mk(EBlock([]));
		}
		return super.parseStructure(id);
	}

	function parseImport(isUsing:Bool):Expr
	{
		var path:Array<String> = [getIdent()];
		var star:Bool = false;
		while (true)
		{
			var tk = token();
			if (tk != TDot)
			{
				push(tk);
				break;
			}
			tk = token();
			switch (tk)
			{
				case TId(name):
					path.push(name);
				case TOp("*"):
					star = true;
					break;
				default:
					unexpected(tk);
			}
		}

		var alias:String = null;
		if (!star && !isUsing && (maybe(TId("as")) || maybe(TId("in"))))
			alias = getIdent();

		var fullPath:String = path.join(".") + (star ? ".*" : "");
		var args:Array<Expr> = [mk(EConst(CString(fullPath)))];
		args.push(alias != null ? mk(EConst(CString(alias))) : mk(EIdent("null")));
		return mk(ECall(mk(EIdent(isUsing ? ScriptInterp.USING_FUNCTION : ScriptInterp.IMPORT_FUNCTION)), args));
	}

	override function readString(until:Int):String
	{
		var value:String = super.readString(until);
		if (until == "'".code && value.indexOf("$") != -1)
			return INTERPOLATION_MARK + value;
		return value;
	}

	function interpolateAll(e:Expr, origin:String):Expr
	{
		if (e == null) return null;
		switch (Tools.expr(e))
		{
			case EConst(CString(value)) if (value.startsWith(INTERPOLATION_MARK)):
				return interpolate(value.substr(INTERPOLATION_MARK.length), e, origin);
			default:
				return Tools.map(e, function(child:Expr) return interpolateAll(child, origin));
		}
	}

	function interpolate(value:String, source:Expr, origin:String):Expr
	{
		var parts:Array<Expr> = [];
		var buffer:StringBuf = new StringBuf();
		var i:Int = 0;
		var length:Int = value.length;

		function flush()
		{
			var text:String = buffer.toString();
			if (text.length > 0) parts.push(copy(EConst(CString(text)), source));
			buffer = new StringBuf();
		}

		while (i < length)
		{
			var char:Int = StringTools.fastCodeAt(value, i);
			if (char != "$".code || i + 1 >= length)
			{
				buffer.addChar(char);
				i++;
				continue;
			}

			var next:Int = StringTools.fastCodeAt(value, i + 1);
			if (next == "$".code)
			{
				buffer.addChar("$".code);
				i += 2;
			}
			else if (next == "{".code)
			{
				var depth:Int = 1;
				var end:Int = i + 2;
				while (end < length && depth > 0)
				{
					var c:Int = StringTools.fastCodeAt(value, end);
					if (c == "{".code) depth++;
					else if (c == "}".code) depth--;
					if (depth > 0) end++;
				}
				if (depth > 0)
				{
					buffer.add(value.substr(i));
					break;
				}
				flush();
				var code:String = value.substring(i + 2, end);
				var inner:Expr = new ScriptParser().parseString(code, origin);
				parts.push(stringify(interpolateAll(inner, origin), source));
				i = end + 1;
			}
			else if (isIdentStart(next))
			{
				var end:Int = i + 1;
				while (end < length && isIdentChar(StringTools.fastCodeAt(value, end)))
					end++;
				flush();
				parts.push(stringify(copy(EIdent(value.substring(i + 1, end)), source), source));
				i = end;
			}
			else
			{
				buffer.addChar(char);
				i++;
			}
		}
		flush();

		if (parts.length == 0) return copy(EConst(CString("")), source);
		var result:Expr = copy(EConst(CString("")), source);
		for (part in parts)
			result = copy(EBinop("+", result, part), source);
		return result;
	}

	function stringify(e:Expr, source:Expr):Expr
		return copy(ECall(copy(EIdent(ScriptInterp.STRING_FUNCTION), source), [e]), source);

	function markGlobals(e:Expr):Expr
	{
		if (e == null) return null;
		switch (Tools.expr(e))
		{
			case EBlock(list):
				return copy(EBlock([for (child in list) markGlobal(child)]), e);
			default:
				return markGlobal(e);
		}
	}

	function markGlobal(e:Expr):Expr
	{
		switch (Tools.expr(e))
		{
			case EVar(_, _, _):
				return copy(EMeta(ScriptInterp.GLOBAL_META, [], e), e);
			default:
				return e;
		}
	}

	static inline function isIdentStart(c:Int):Bool
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || c == "_".code;

	static inline function isIdentChar(c:Int):Bool
		return isIdentStart(c) || (c >= "0".code && c <= "9".code);

	static function copy(def:ExprDef, source:Expr):Expr
	{
		#if hscriptPos
		return {e: def, pmin: source.pmin, pmax: source.pmax, origin: source.origin, line: source.line};
		#else
		return def;
		#end
	}

	static function get_defines():Map<String, Dynamic>
	{
		if (_defines != null) return _defines;
		_defines = new Map();
		_defines.set("PSYCH", true);
		_defines.set("FUNKIN_PSYCH", true);
		#if mobile _defines.set("mobile", true); #end
		#if desktop _defines.set("desktop", true); #end
		#if android _defines.set("android", true); #end
		#if ios _defines.set("ios", true); #end
		#if windows _defines.set("windows", true); #end
		#if linux _defines.set("linux", true); #end
		#if mac _defines.set("mac", true); #end
		#if cpp _defines.set("cpp", true); #end
		#if hl _defines.set("hl", true); #end
		#if html5 _defines.set("html5", true); #end
		#if sys _defines.set("sys", true); #end
		#if debug _defines.set("debug", true); #end
		#if MODS_ALLOWED _defines.set("MODS_ALLOWED", true); #end
		#if LUA_ALLOWED _defines.set("LUA_ALLOWED", true); #end
		#if HSCRIPT_ALLOWED _defines.set("HSCRIPT_ALLOWED", true); #end
		#if VIDEOS_ALLOWED _defines.set("VIDEOS_ALLOWED", true); #end
		#if DISCORD_ALLOWED _defines.set("DISCORD_ALLOWED", true); #end
		#if ACHIEVEMENTS_ALLOWED _defines.set("ACHIEVEMENTS_ALLOWED", true); #end
		#if TRANSLATIONS_ALLOWED _defines.set("TRANSLATIONS_ALLOWED", true); #end
		#if BASE_GAME_FILES _defines.set("BASE_GAME_FILES", true); #end
		#if CRASH_HANDLER _defines.set("CRASH_HANDLER", true); #end
		#if PSYCH_WATERMARKS _defines.set("PSYCH_WATERMARKS", true); #end
		#if flxanimate _defines.set("flxanimate", true); #end
		return _defines;
	}
}
#end
