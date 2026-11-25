package funkin.util;

class BuildInfo
{
	#if !macro
	public static final gitHash:String = define("GIT_HASH");
	public static final gitBranch:String = define("GIT_BRANCH");
	public static final gitModified:Bool = define("GIT_MODIFIED") != null;
	public static final buildDate:String = define("BUILD_DATE");
	public static final buildNumber:String = define("BUILD_NUMBER");
	public static final ciBuild:Bool = define("CI_BUILD") != null;

	public static function describe():String
	{
		var parts:Array<String> = [];
		if (gitHash != null) parts.push(gitHash + (gitModified ? '*' : ''));
		if (buildNumber != null) parts.push('#' + buildNumber);
		return parts.join(' ');
	}
	#end

	static macro function define(name:String):haxe.macro.Expr
	{
		var value:String = haxe.macro.Context.definedValue(name);
		return value == null ? macro null : macro $v{value};
	}
}
