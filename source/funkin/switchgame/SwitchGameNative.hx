package funkin.switchgame;

#if cpp
@:include('switchgame.h')
extern class SwitchGameNative
{
	@:native('::switchgame::version') static function version():cpp.ConstCharStar;
	@:native('::switchgame::platform') static function platform():cpp.ConstCharStar;
	@:native('::switchgame::lastError') static function lastError():cpp.ConstCharStar;
	@:native('::switchgame::launchArguments') static function launchArguments():cpp.ConstCharStar;
	@:native('::switchgame::pathExists') static function pathExists(path:cpp.ConstCharStar):Bool;
	@:native('::switchgame::packageInstalled') static function packageInstalled(packageName:cpp.ConstCharStar):Bool;
	@:native('::switchgame::urlAvailable') static function urlAvailable(url:cpp.ConstCharStar):Bool;
	@:native('::switchgame::launchExecutable') static function launchExecutable(path:cpp.ConstCharStar, arguments:cpp.ConstCharStar, workingDirectory:cpp.ConstCharStar):Bool;
	@:native('::switchgame::launchPackage') static function launchPackage(packageName:cpp.ConstCharStar, arguments:cpp.ConstCharStar):Bool;
	@:native('::switchgame::launchUrl') static function launchUrl(url:cpp.ConstCharStar):Bool;
}
#end
