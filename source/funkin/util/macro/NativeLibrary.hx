package funkin.util.macro;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

class NativeLibrary
{
	public static function build(name:String):Array<Field>
	{
		var cls = Context.getLocalClass().get();
		var main:String = Context.resolvePath('Main.hx');
		var root:String = Path.normalize(Path.join([Path.directory(sys.FileSystem.absolutePath(main)), '..', 'native', name]));
		root = root.split('\\').join('/');
		if (!sys.FileSystem.exists('$root/Build.xml')) Context.error('Native library "$name" was not found at $root', Context.currentPos());
		cls.meta.add(':buildXml', [macro $v{'<include name="$root/Build.xml"/>'}], Context.currentPos());
		return Context.getBuildFields();
	}
}
#end
