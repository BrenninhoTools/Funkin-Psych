package funkin.play.stages.modules;

import funkin.data.DataUtil;
import funkin.play.character.Character;
import funkin.play.notes.Note.EventNote;
import funkin.play.stages.objects.PhillyGlowGradient;
import funkin.play.stages.objects.PhillyGlowParticle;

class PhillyGlow extends BaseStage
{
	var options:Dynamic;
	var eventName:String = 'Philly Glow';
	var colors:Array<FlxColor> = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];
	var black:FlxSprite;
	var gradient:PhillyGlowGradient;
	var particles:FlxTypedGroup<PhillyGlowParticle>;
	var windowGlow:FlxSprite;
	var curLight:Int = -1;

	override function create()
	{
		options = StageModules.consumeOptions();
		if (options.event != null) eventName = Std.string(options.event);
		if (options.colors != null)
			colors = [for (color in (cast options.colors:Array<Dynamic>)) funkin.data.ui.UIData.parseColor(color, FlxColor.WHITE)];
	}

	function object(key:String, fallback:String):FlxSprite
	{
		var name:String = Reflect.field(options, key) != null ? Std.string(Reflect.field(options, key)) : fallback;
		var found:Dynamic = getStageObject(name);
		return Std.isOfType(found, FlxSprite) ? cast found : null;
	}

	override function eventPushed(event:EventNote)
	{
		if (event.event != eventName || black != null) return;

		var street:FlxSprite = object('street', 'street');
		var window:FlxSprite = object('window', 'window');

		black = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		black.visible = false;
		if (street != null) insert(members.indexOf(street), black);
		else addBehindGF(black);

		if (window != null)
		{
			windowGlow = new FlxSprite(window.x, window.y).loadGraphicFromSprite(window);
			windowGlow.scrollFactor.set(window.scrollFactor.x, window.scrollFactor.y);
			windowGlow.scale.set(window.scale.x, window.scale.y);
			windowGlow.updateHitbox();
			windowGlow.antialiasing = window.antialiasing;
			windowGlow.visible = false;
			insert(members.indexOf(black) + 1, windowGlow);
		}

		var gradientPos:Array<Float> = DataUtil.vector(options.gradient, -400, 225);
		gradient = new PhillyGlowGradient(gradientPos[0], gradientPos[1]);
		gradient.visible = false;
		insert(members.indexOf(black) + 1, gradient);
		if (!Save.data.flashing) gradient.intendedAlpha = 0.7;

		Paths.image('philly/particle');
		particles = new FlxTypedGroup<PhillyGlowParticle>();
		particles.visible = false;
		insert(members.indexOf(gradient) + 1, particles);
	}

	override function update(elapsed:Float)
	{
		if (particles != null)
			particles.forEachAlive(function(particle:PhillyGlowParticle) if (particle.alpha <= 0) particle.kill());
	}

	function flash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if (!Save.data.flashing) color.alphaFloat = 0.5;
		FlxG.camera.flash(color, 0.15, null, true);
		if (Save.data.camZooms)
		{
			FlxG.camera.zoom += 0.5;
			camHUD.zoom += 0.1;
		}
	}

	override function eventCalled(name:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (name != eventName || black == null) return;
		var lightId:Int = Math.round(flValue1 != null && flValue1 > 0 ? flValue1 : 0);
		var chars:Array<Character> = [boyfriend, gf, dad];
		var street:FlxSprite = object('street', 'street');
		switch (lightId)
		{
			case 0:
				if (!gradient.visible) return;
				flash();
				black.visible = false;
				if (windowGlow != null) windowGlow.visible = false;
				gradient.visible = false;
				particles.visible = false;
				curLight = -1;
				for (who in chars) if (who != null) who.color = FlxColor.WHITE;
				if (street != null) street.color = FlxColor.WHITE;

			case 1:
				curLight = FlxG.random.int(0, colors.length - 1, [curLight]);
				var color:FlxColor = colors[curLight];
				if (!gradient.visible)
				{
					flash();
					black.visible = true;
					black.alpha = 1;
					if (windowGlow != null) windowGlow.visible = true;
					gradient.visible = true;
					particles.visible = true;
				}
				else if (Save.data.flashing)
				{
					var lower:FlxColor = color;
					lower.alphaFloat = 0.25;
					FlxG.camera.flash(lower, 0.5, null, true);
				}

				var charColor:FlxColor = color;
				charColor.saturation *= Save.data.flashing ? 0.75 : 0.5;
				for (who in chars) if (who != null) who.color = charColor;
				particles.forEachAlive((particle:PhillyGlowParticle) -> particle.color = color);
				gradient.color = color;
				if (windowGlow != null) windowGlow.color = color;
				color.brightness *= 0.5;
				if (street != null) street.color = color;

			case 2:
				if (!Save.data.lowQuality && curLight > -1)
				{
					var count:Int = FlxG.random.int(8, 12);
					var width:Float = 2000 / count;
					var color:FlxColor = colors[curLight];
					for (j in 0...3)
						for (i in 0...count)
						{
							var particle:PhillyGlowParticle = particles.recycle(PhillyGlowParticle);
							particle.x = -400 + width * i + FlxG.random.float(-width / 5, width / 5);
							particle.y = gradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40);
							particle.color = color;
							particle.start();
							particles.add(particle);
						}
				}
				gradient.bop();
		}
	}
}
