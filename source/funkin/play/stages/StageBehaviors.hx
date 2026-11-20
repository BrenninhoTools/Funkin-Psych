package funkin.play.stages;

import flixel.addons.effects.FlxTrail;
import flixel.FlxObject;
import funkin.data.DataUtil;
import funkin.play.GameOverSubstate;
import funkin.play.character.Character;
import funkin.play.stages.BaseStage.Countdown;

class StageBehaviors extends BaseStage
{
	static var pending:Array<Dynamic> = null;
	static var pendingObjects:Array<Dynamic> = null;

	var behaviors:Array<Dynamic> = [];
	var objectData:Map<String, Dynamic> = [];
	var nextAllowed:Map<Int, Int> = [];
	var lastColors:Map<String, Int> = [];
	var beatObjects:Array<Dynamic> = [];

	public static function spawn(list:Array<Dynamic>, objects:Array<Dynamic>):StageBehaviors
	{
		pending = list != null ? list : [];
		pendingObjects = objects != null ? objects : [];
		return new StageBehaviors();
	}

	override function create()
	{
		behaviors = pending != null ? pending : [];
		for (object in (pendingObjects != null ? pendingObjects : []))
			if (object != null && object.name != null) objectData.set(Std.string(object.name), object);
		pending = null;
		pendingObjects = null;

		for (num => behavior in behaviors)
		{
			var cooldown:Dynamic = behavior.initialCooldown;
			if (cooldown != null) nextAllowed.set(num, DataUtil.toInt(cooldown, 0));
		}

		fire('create');
		for (num => behavior in behaviors)
		{
			if (behavior == null) continue;
			switch (trigger(behavior))
			{
				case 'cutscene':
					if (isStoryMode && !seenCutscene && matches(behavior, num))
						setStartCallback(() -> run(behavior.actions, null));
				case 'endCutscene':
					if (songAllowed(behavior) && conditions(behavior))
						setEndCallback(function()
						{
							var nextSong:String = PlayState.storyPlaylist != null && PlayState.storyPlaylist.length > 1 ? Paths.formatToSongPath(PlayState.storyPlaylist[1]) : null;
							var required:Dynamic = behavior.nextSong;
							if (required != null && (nextSong == null || !listOf(required).contains(nextSong)))
							{
								endSong();
								return;
							}
							run(behavior.actions, null);
						});
			}
		}
	}

	override function createPost()
	{
		for (name in objectData.keys())
		{
			var object:Dynamic = getStageObject(name);
			if (object != null && Reflect.isFunction(Reflect.field(object, 'beatHit'))) beatObjects.push(object);
		}
		fire('createPost');
	}

	override function update(elapsed:Float)
	{
		fire('update', null, elapsed);
	}

	override function beatHit()
	{
		for (object in beatObjects) Reflect.callMethod(object, Reflect.field(object, 'beatHit'), [curBeat]);
		fire('beat', curBeat);
	}

	override function stepHit()
		fire('step', curStep);

	override function sectionHit()
		fire('section', curSection);

	override function countdownTick(count:Countdown, num:Int)
		fire('countdown', num);

	override function startSong()
		fire('songStart');

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		for (num => behavior in behaviors)
		{
			if (behavior == null || trigger(behavior) != 'event') continue;
			if (behavior.event == null || !listOf(behavior.event).contains(eventName)) continue;
			var v1:String = value1 != null ? value1.toLowerCase().trim() : '';
			if (behavior.value1 != null && !listOf(behavior.value1).contains(v1)) continue;
			if (behavior.value1Not != null && listOf(behavior.value1Not).contains(v1)) continue;
			if (!matches(behavior, num)) continue;
			run(behavior.actions, {value1: value1, value2: value2, flValue1: flValue1, flValue2: flValue2});
		}
	}

	function trigger(behavior:Dynamic):String
		return behavior.on != null ? Std.string(behavior.on) : '';

	function fire(name:String, ?counter:Null<Int>, ?elapsed:Float = 0)
	{
		for (num => behavior in behaviors)
		{
			if (behavior == null || trigger(behavior) != name) continue;
			if (counter != null)
			{
				var every:Int = DataUtil.toInt(behavior.every, 1);
				if (every > 1 && (counter - DataUtil.toInt(behavior.offset, 0)) % every != 0) continue;
				if (nextAllowed.exists(num) && counter <= nextAllowed.get(num)) continue;
			}
			if (!matches(behavior, num)) continue;
			if (counter != null && behavior.cooldown != null)
			{
				var range:Array<Int> = DataUtil.intArray(behavior.cooldown);
				var min:Int = range.length > 0 ? range[0] : 0;
				var max:Int = range.length > 1 ? range[1] : min;
				nextAllowed.set(num, counter + FlxG.random.int(min, max));
			}
			run(behavior.actions, {elapsed: elapsed, counter: counter});
		}
	}

	function songAllowed(behavior:Dynamic):Bool
	{
		if (behavior.songs != null && !listOf(behavior.songs).contains(songName)) return false;
		if (behavior.notSongs != null && listOf(behavior.notSongs).contains(songName)) return false;
		return true;
	}

	function matches(behavior:Dynamic, num:Int):Bool
	{
		if (!songAllowed(behavior)) return false;
		if (!conditions(behavior)) return false;
		if (behavior.chance != null && !FlxG.random.bool(DataUtil.toFloat(behavior.chance, 100))) return false;
		return true;
	}

	function conditions(data:Dynamic):Bool
	{
		var cond:Dynamic = data.when != null ? data.when : data;
		if (cond.storyMode != null && DataUtil.toBool(cond.storyMode) != isStoryMode) return false;
		if (cond.lowQuality != null && DataUtil.toBool(cond.lowQuality) != Save.data.lowQuality) return false;
		if (cond.flashing != null && DataUtil.toBool(cond.flashing) != Save.data.flashing) return false;
		if (cond.camZooms != null && DataUtil.toBool(cond.camZooms) != Save.data.camZooms) return false;
		if (cond.seenCutscene != null && DataUtil.toBool(cond.seenCutscene) != seenCutscene) return false;
		return true;
	}

	function listOf(value:Dynamic):Array<String>
	{
		var list:Array<Dynamic> = Std.isOfType(value, Array) ? value : [value];
		return [for (entry in list) Std.string(entry).toLowerCase().trim()];
	}

	function run(actions:Array<Dynamic>, context:Dynamic)
	{
		if (actions == null) return;
		for (action in actions)
		{
			if (action == null) continue;
			if (action.when != null && !conditions(action)) continue;
			var delay:Float = DataUtil.toFloat(action.delay, 0);
			if (delay > 0) new FlxTimer().start(delay, (_) -> execute(action, context));
			else execute(action, context);
		}
	}

	function targets(action:Dynamic):Array<Dynamic>
	{
		var names:Array<Dynamic> = action.target == null ? [] : (Std.isOfType(action.target, Array) ? action.target : [action.target]);
		var result:Array<Dynamic> = [];
		for (raw in names)
		{
			var object:Dynamic = resolve(Std.string(raw));
			if (object != null) result.push(object);
		}
		return result;
	}

	function resolve(name:String):Dynamic
	{
		return switch (name)
		{
			case 'bf', 'boyfriend', 'player': boyfriend;
			case 'dad', 'opponent': dad;
			case 'gf', 'girlfriend': gf;
			case 'camGame', 'camera': camGame;
			case 'camHUD', 'hud': camHUD;
			case 'camOther': camOther;
			case 'characters': null;
			default: getStageObject(name);
		}
	}

	function characters(action:Dynamic):Array<Dynamic>
	{
		if (action.target == 'characters') return [boyfriend, dad, gf].filter(c -> c != null);
		return targets(action);
	}

	function value(raw:Dynamic, ?context:Dynamic):Dynamic
	{
		if (Std.isOfType(raw, String))
		{
			var text:String = raw;
			if (text == "$defaultCamZoom") return defaultCamZoom;
			if (text.startsWith("$") && context != null && Reflect.hasField(context, text.substr(1))) return Reflect.field(context, text.substr(1));
			if (text.startsWith('#')) return funkin.data.ui.UIData.parseColor(text, FlxColor.WHITE);
		}
		return raw;
	}

	function applyProps(target:Dynamic, props:Dynamic, relative:Bool, ?context:Dynamic)
	{
		if (props == null) return;
		for (field in Reflect.fields(props))
		{
			var raw:Dynamic = value(Reflect.field(props, field), context);
			if (raw == null) continue;
			if (field == 'scale' && Std.isOfType(target, FlxSprite))
			{
				var vec:Array<Float> = DataUtil.vector(raw, 1, 1);
				(cast target:FlxSprite).scale.set(vec[0], vec[1]);
				continue;
			}
			if (relative)
			{
				var current:Float = DataUtil.toFloat(Reflect.getProperty(target, field), 0);
				Reflect.setProperty(target, field, current + DataUtil.toFloat(raw, 0));
			}
			else Reflect.setProperty(target, field, raw);
		}
	}

	function execute(action:Dynamic, context:Dynamic)
	{
		var kind:String = action.action != null ? Std.string(action.action) : '';
		switch (kind)
		{
			case 'play':
				var anim:String = Std.string(action.anim);
				for (target in characters(action))
				{
					if (Std.isOfType(target, Character))
					{
						var char:Character = cast target;
						if (!char.hasAnimation(anim)) continue;
						char.playAnim(anim, action.force != false);
						if (DataUtil.toBool(action.special)) char.specialAnim = true;
					}
					else if (Std.isOfType(target, FlxSprite))
					{
						var spr:FlxSprite = cast target;
						if (!spr.animation.exists(anim)) continue;
						if (Std.isOfType(spr, funkin.scripting.luascript.ModchartSprite)) (cast spr:funkin.scripting.luascript.ModchartSprite).playAnim(anim, action.force != false);
						else spr.animation.play(anim, action.force != false);
						if (DataUtil.toBool(action.show)) spr.visible = true;
						if (DataUtil.toBool(action.hideOnFinish))
						{
							var watched:String = anim;
							spr.animation.onFinish.addOnce(function(name:String) if (name == watched) spr.visible = false);
						}
					}
				}

			case 'dance':
				var names:Array<Dynamic> = action.target == null ? [] : (Std.isOfType(action.target, Array) ? action.target : [action.target]);
				for (raw in names)
				{
					var target:Dynamic = resolve(Std.string(raw));
					if (target == null) continue;
					if (Reflect.isFunction(Reflect.field(target, 'dance')))
						Reflect.callMethod(target, Reflect.field(target, 'dance'), action.force != null ? [action.force == true] : []);
					else if (Std.isOfType(target, FlxSprite))
					{
						var spr:FlxSprite = cast target;
						var data:Dynamic = objectData.get(Std.string(raw));
						var anim:String = data != null && data.firstAnimation != null ? data.firstAnimation : (spr.animation.curAnim != null ? spr.animation.curAnim.name : null);
						if (anim == null) continue;
						if (Std.isOfType(spr, funkin.scripting.luascript.ModchartSprite)) (cast spr:funkin.scripting.luascript.ModchartSprite).playAnim(anim, true);
						else spr.animation.play(anim, true);
					}
				}

			case 'call':
				for (target in targets(action))
				{
					var fn:Dynamic = Reflect.field(target, Std.string(action.method));
					if (Reflect.isFunction(fn)) Reflect.callMethod(target, fn, action.args != null ? action.args : []);
				}

			case 'sound':
				var names:Array<Dynamic> = action.sounds != null ? action.sounds : [action.sound];
				var name:String = Std.string(names[FlxG.random.int(0, names.length - 1)]);
				FunkinSound.playOnce(name, DataUtil.toFloat(action.volume, 1));

			case 'music':
				FunkinSound.playMusic(Std.string(action.music), action.fadeIn != null ? 0 : DataUtil.toFloat(action.volume, 1));
				if (action.fadeIn != null && FlxG.sound.music != null)
					FlxG.sound.music.fadeIn(DataUtil.toFloat(action.fadeIn, 1), 0, DataUtil.toFloat(action.volume, 1));

			case 'set':
				for (target in targets(action)) applyProps(target, action.props, false, context);

			case 'add':
				for (target in targets(action)) applyProps(target, action.props, true, context);

			case 'tween':
				for (target in targets(action))
				{
					var props:Dynamic = {};
					if (action.props != null)
						for (field in Reflect.fields(action.props)) Reflect.setField(props, field, value(Reflect.field(action.props, field), context));
					if (action.from != null) applyProps(target, action.from, false);
					var hide:Bool = DataUtil.toBool(action.hideOnComplete);
					FlxTween.tween(target, props, DataUtil.toFloat(action.duration, 1), {
						ease: funkin.scripting.luascript.LuaUtils.getTweenEaseByString(action.ease != null ? Std.string(action.ease) : 'linear'),
						startDelay: DataUtil.toFloat(action.startDelay, 0),
						onComplete: function(_) if (hide) Reflect.setProperty(target, 'visible', false)
					});
				}

			case 'color':
				var colors:Array<Dynamic> = action.colors != null ? action.colors : [];
				if (colors.length < 1) return;
				var key:String = Std.string(action.target);
				var last:Int = lastColors.exists(key) ? lastColors.get(key) : -1;
				var index:Int = colors.length > 1 ? FlxG.random.int(0, colors.length - 1, [last]) : 0;
				lastColors.set(key, index);
				var color:FlxColor = funkin.data.ui.UIData.parseColor(colors[index], FlxColor.WHITE);
				for (target in targets(action)) Reflect.setProperty(target, 'color', color);

			case 'fade':
				var speed:Float = DataUtil.toFloat(action.speed, 1);
				if (action.beatScaled != false) speed *= Conductor.crochet / 1000;
				var elapsed:Float = context != null && context.elapsed != null ? context.elapsed : FlxG.elapsed;
				for (target in targets(action))
				{
					var alpha:Float = DataUtil.toFloat(Reflect.getProperty(target, 'alpha'), 1) - speed * elapsed;
					Reflect.setProperty(target, 'alpha', Math.max(0, alpha));
				}

			case 'zoom':
				if (!Save.data.camZooms) return;
				FlxG.camera.zoom += DataUtil.toFloat(action.game, 0);
				camHUD.zoom += DataUtil.toFloat(action.hud, 0);
				if (action.settle != null && !game.camZooming)
				{
					var duration:Float = DataUtil.toFloat(action.settle, 0.5);
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, duration);
					FlxTween.tween(camHUD, {zoom: 1}, duration);
				}

			case 'cameraZoom':
				FlxG.camera.zoom = DataUtil.toFloat(value(action.zoom), defaultCamZoom);

			case 'flash':
				var cam:FlxCamera = action.camera == 'hud' ? camHUD : (action.camera == 'other' ? camOther : FlxG.camera);
				var color:FlxColor = funkin.data.ui.UIData.parseColor(action.color, FlxColor.WHITE);
				if (!Save.data.flashing && action.reduced != null) color.alphaFloat = DataUtil.toFloat(action.reduced, 0.5);
				cam.flash(color, DataUtil.toFloat(action.duration, 0.5), null, action.force != false);

			case 'cameraFade':
				var color:FlxColor = funkin.data.ui.UIData.parseColor(action.color, FlxColor.WHITE);
				FlxG.camera.fade(color, DataUtil.toFloat(action.duration, 1), DataUtil.toBool(action.fadeIn), null, true);

			case 'focus':
				var point:Array<Float> = DataUtil.vector(action.offset);
				var target:Dynamic = action.target != null ? resolve(Std.string(action.target)) : null;
				if (target != null && Std.isOfType(target, FlxObject))
				{
					var mid = (cast target:FlxObject).getMidpoint();
					FlxG.camera.focusOn(new FlxPoint(mid.x + point[0], mid.y + point[1]));
					mid.put();
				}
				else if (action.point != null)
				{
					var pos:Array<Float> = DataUtil.vector(action.point);
					FlxG.camera.focusOn(new FlxPoint(pos[0], pos[1]));
				}

			case 'spotlight':
				var target:Dynamic = resolve(Std.string(action.on));
				for (light in targets(action))
				{
					if (target == null || !Std.isOfType(light, FlxSprite) || !Std.isOfType(target, FlxSprite)) continue;
					var spr:FlxSprite = cast light;
					var who:FlxSprite = cast target;
					var offset:Array<Float> = DataUtil.vector(action.offset);
					spr.setPosition(who.getGraphicMidpoint().x - spr.width / 2 + offset[0], who.y + who.height - spr.height + offset[1]);
				}

			case 'hud':
				camHUD.visible = action.visible != false;

			case 'cutscene':
				inCutscene = action.active != false;

			case 'pause':
				canPause = action.allowed != false;

			case 'startCountdown':
				startCountdown();

			case 'endSong':
				endSong();

			case 'defaultZoom':
				defaultCamZoom = action.add != null ? defaultCamZoom + DataUtil.toFloat(action.add, 0) : DataUtil.toFloat(action.value, defaultCamZoom);

			case 'trail':
				for (target in targets(action))
				{
					if (!Std.isOfType(target, FlxSprite)) continue;
					var trail:FlxTrail = new FlxTrail(cast target, null, DataUtil.toInt(action.length, 4), DataUtil.toInt(action.frameDelay, 24), DataUtil.toFloat(action.alpha, 0.3), DataUtil.toFloat(action.diff, 0.069));
					if (target == dad) addBehindDad(trail);
					else if (target == boyfriend) addBehindBF(trail);
					else addBehindGF(trail);
				}

			case 'gameOver':
				var song = PlayState.SONG;
				if (action.sound != null && (song.gameOverSound == null || song.gameOverSound.trim().length < 1)) GameOverSubstate.deathSoundName = action.sound;
				if (action.loop != null && (song.gameOverLoop == null || song.gameOverLoop.trim().length < 1)) GameOverSubstate.loopSoundName = action.loop;
				if (action.end != null && (song.gameOverEnd == null || song.gameOverEnd.trim().length < 1)) GameOverSubstate.endSoundName = action.end;
				if (action.character != null && (song.gameOverChar == null || song.gameOverChar.trim().length < 1)) GameOverSubstate.characterName = action.character;

			case 'precache':
				if (action.sounds != null) for (sound in (cast action.sounds:Array<Dynamic>)) Paths.sound(Std.string(sound));
				if (action.images != null) for (image in (cast action.images:Array<Dynamic>)) Paths.image(Std.string(image));

			case 'play3D':
				#if foxlite
				for (target in targets(action))
					if (Std.isOfType(target, funkin.graphics.three.Scene3D))
						(cast target:funkin.graphics.three.Scene3D).playAnimation(Std.string(action.object), Std.string(action.anim));
				#end

			case 'stopTweens':
				for (target in targets(action)) FlxTween.cancelTweensOf(target);

			default:
				FlxG.log.warn('Unknown stage action "$kind"');
		}
	}
}
