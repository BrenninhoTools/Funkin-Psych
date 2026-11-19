package funkin.audio.miniaudio;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;

class MiniAudioMacro
{
	public static function build():Array<Field>
	{
		var cls = Context.getLocalClass().get();
		var main:String = Context.resolvePath('Main.hx');
		var root:String = Path.normalize(Path.join([Path.directory(sys.FileSystem.absolutePath(main)), '..', 'native', 'miniaudio']));
		root = root.split('\\').join('/');
		var xml:String = '<include name="$root/Build.xml"/>';
		cls.meta.add(':buildXml', [macro $v{xml}], Context.currentPos());
		return Context.getBuildFields();
	}
}
#end
