# Cppia scripting

Cppia scripts are Haxe code compiled to bytecode and run by the game's own hxcpp runtime. They are faster than HScript and can use every class compiled into the game.

Cppia is enabled on desktop and mobile builds. Build with `-DNO_CPPIA` to disable it.

## Host class list

The game is built with `-D scriptable` and `-D dll_export=export_classes.info`. After a build, `export_classes.info` is written to the hxcpp output folder, for example `export/release/windows/haxe/export_classes.info`. Scripts must be compiled against the file from the same build they will run on.

## Writing a script

```haxe
import funkin.scripting.cppia.CppiaScript;
import flixel.FlxSprite;

class MyScript extends CppiaScript
{
	var logo:FlxSprite;

	public function onCreatePost()
	{
		logo = new FlxSprite(100, 100).loadGraphic(Paths.image('logo'));
		add(logo);
	}

	public function onBeatHit()
	{
		logo.scale.set(1.1, 1.1);
	}

	public function onUpdate(elapsed:Float)
	{
		logo.scale.x = logo.scale.y = flixel.math.FlxMath.lerp(logo.scale.x, 1, elapsed * 9);
	}
}
```

The class with the same name as the `.cppia` file is created when the script loads. Any public method named like a PlayState callback (`onCreate`, `onCreatePost`, `onUpdate`, `onUpdatePost`, `onBeatHit`, `onStepHit`, `onSectionHit`, `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `onEvent`, `onDestroy`...) is called by the game with the same arguments Lua and HScript receive. Return `LuaUtils.Function_StopAll` to stop the call chain.

If the file has no class with its name, the script's `static function main()` runs instead. Call `funkin.scripting.cppia.CppiaHandler.register(object)` there to receive callbacks on any object.

## Compiling

```
haxe -cp scripts -main MyScript -cppia MyScript.cppia -D dll_import=path/to/export_classes.info -L flixel -L openfl -L lime
```

Use the same haxelib versions as the game (see `.hxpkg`) and add `-cp` for the game's `source` folder so the engine classes are known at compile time.

## Where to put scripts

| Folder | When it runs |
|---|---|
| `mods/<mod>/scripts/cppia/` | Loaded with the mod and active everywhere. Receives `onLoad` and `onUnload`, plus every PlayState callback. |
| `mods/<mod>/scripts/` | Loaded for every song. |
| `mods/<mod>/data/songs/<song>/` | Loaded only for that song. |

HScript can import classes defined in global cppia modules by their full class name.
