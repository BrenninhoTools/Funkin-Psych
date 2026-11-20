package funkin.ui.title;

import funkin.ui.debug.ChartingState;
import funkin.ui.freeplay.FreeplayState;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import funkin.shaders.ColorSwap;
import funkin.data.DataUtil;

import funkin.ui.story.StoryMenuState;
import funkin.ui.mainmenu.MainMenuState;

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;
	
	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	final easterEggKeys:Array<String> = [
		'SHADOW', 'RIVEREN', 'BBPANZU', 'PESSY'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		if(!initialized)
		{
			Save.loadPrefs();
			Language.reloadPhrases();
		}

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if(!initialized)
		{
			if(Save.main.data != null && Save.main.data.fullscreen)
			{
				FlxG.fullscreen = Save.main.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (Save.main.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = Save.main.data.weekCompleted;
		}

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(Save.main.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var titleAtlas:FlxAnimate;
	var swagShader:ColorSwap = null;
	var menu:funkin.data.menu.MenuData;
	var introSprites:Map<String, FlxSprite> = [];

	public static function defaultData():Dynamic
	{
		return {
			version: funkin.data.menu.MenuData.VERSION,
			music: {name: 'freakyMenu', bpm: 102, volume: 0.7, fadeIn: 4},
			background: {image: '', color: null},
			logo: {render: {type: 'sparrow', image: 'logoBumpin'}, position: [-150, -100], animation: {prefix: 'logo bumpin', fps: 24}},
			logoOnTop: false,
			character: {
				render: {type: 'sparrow', image: 'gfDanceTitle'},
				position: [512, 50.4],
				animation: 'gfDance',
				fps: 24,
				idle: false,
				danceLeft: [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
				danceRight: [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
			},
			enter: {render: {type: 'atlas', image: 'title-screen-text'}, position: [100, 576], mobilePosition: [50, 576], idle: 'Idle', press: 'Confirm', colors: ['#33FFFF', '#3333CC'], alphas: [1, 0.64]},
			flash: {color: '#FFFFFF', duration: 4},
			confirm: {sound: 'confirmMenu', volume: 0.7, delay: 1, flash: 1},
			introTexts: 'data/introText.txt',
			intro: [
				{beat: 2, action: 'create', text: ['The', 'Funkin Crew Inc']},
				{beat: 4, action: 'add', text: ['presents']},
				{beat: 5, action: 'clear'},
				{beat: 6, action: 'create', text: ['In association', 'with']},
				{beat: 8, action: 'add', text: ['newgrounds'], show: 'newgrounds'},
				{beat: 9, action: 'clear', hide: 'newgrounds'},
				{beat: 10, action: 'create', text: ['{wacky0}']},
				{beat: 12, action: 'add', text: ['{wacky1}']},
				{beat: 13, action: 'clear'},
				{beat: 14, action: 'add', text: ['Friday']},
				{beat: 15, action: 'add', text: ['Night']},
				{beat: 16, action: 'add', text: ['Funkin']},
				{beat: 17, action: 'skip'}
			],
			introSprites: [
				{name: 'newgrounds', image: 'newgrounds_logo', position: [0, 374.4], scale: [0.8, 0.8], centerX: true, randomVariants: true}
			],
			sprites: []
		};
	}

	function startIntro()
	{
		persistentUpdate = true;
		loadJsonData();
		#if TITLE_SCREEN_EASTER_EGG easterEggData(); #end

		if (!initialized && FlxG.sound.music == null)
			FunkinSound.playMusic(menu.string('music', 'name', 'freakyMenu'), 0);
		Conductor.bpm = menu.float('music', 'bpm', 102);

		var bgInfo:Dynamic = menu.element('background');
		if (bgInfo.color != null)
		{
			var fill:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			fill.scale.set(FlxG.width, FlxG.height);
			fill.updateHitbox();
			fill.color = funkin.data.ui.UIData.parseColor(bgInfo.color, FlxColor.BLACK);
			fill.scrollFactor.set();
			add(fill);
		}
		if (bgInfo.image != null && Std.string(bgInfo.image).trim().length > 0)
		{
			var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(Std.string(bgInfo.image)));
			bg.antialiasing = Save.data.antialiasing;
			add(bg);
			funkin.mobile.screen.WideScreen.fit(bg);
		}

		var back:FlxSpriteGroup = new FlxSpriteGroup();
		menu.createSprites(back, null, false, variables);
		add(back);

		var logoPos:Array<Float> = menu.position('logo');
		logoBl = new FlxSprite(logoPos[0] + funkin.mobile.screen.WideScreen.offset, logoPos[1]);
		loadFrames(logoBl, menu.element('logo'));
		var logoAnim:Dynamic = menu.element('logo').animation;
		addAnim(logoBl, 'bump', logoAnim != null && logoAnim.prefix != null ? logoAnim.prefix : 'logo bumpin', null, logoAnim != null ? DataUtil.toFloat(logoAnim.fps, 24) : 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();
		logoBl.visible = menu.visible('logo');

		var gfPos:Array<Float> = menu.position('character');
		gfDance = new FlxSprite(gfPos[0] + funkin.mobile.screen.WideScreen.offset, gfPos[1]);
		loadFrames(gfDance, menu.element('character'));
		gfDance.visible = menu.visible('character');

		if(Save.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
		}

		var animationName:String = menu.string('character', 'animation', 'gfDance');
		var fps:Float = menu.float('character', 'fps', 24);
		useIdle = menu.bool('character', 'idle', false);
		if(!useIdle)
		{
			addAnim(gfDance, 'danceLeft', animationName, DataUtil.intArray(menu.element('character').danceLeft), fps, false);
			addAnim(gfDance, 'danceRight', animationName, DataUtil.intArray(menu.element('character').danceRight), fps, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			addAnim(gfDance, 'idle', animationName, null, fps, false);
			gfDance.animation.play('idle');
		}

		var colors:Array<Dynamic> = menu.element('enter').colors;
		if (colors != null && colors.length > 1)
			titleTextColors = [funkin.data.ui.UIData.parseColor(colors[0], 0xFF33FFFF), funkin.data.ui.UIData.parseColor(colors[1], 0xFF3333CC)];
		var alphas:Array<Dynamic> = menu.element('enter').alphas;
		if (alphas != null && alphas.length > 1)
			titleTextAlphas = [DataUtil.toFloat(alphas[0], 1), DataUtil.toFloat(alphas[1], 0.64)];

		var enterInfo:Dynamic = menu.element('enter');
		var enterPos:Array<Float> = menu.position('enter');
		#if mobile
		if (enterInfo.mobilePosition != null) enterPos = DataUtil.vector(enterInfo.mobilePosition, enterPos[0], enterPos[1]);
		#end
		var enterRender:Dynamic = enterInfo.render != null ? enterInfo.render : enterInfo;
		var enterImage:String = funkin.graphics.FrameLoader.joinImages(enterRender.image);
		#if mobile
		if (Paths.fileExists('images/$enterImage-mobile/Animation.json', TEXT)) enterImage += '-mobile';
		#end
		if (funkin.graphics.FrameLoader.resolveType(enterImage, enterRender.type) == 'atlas')
		{
			var atlas:funkin.ui.freeplay.FreeplayAnimate = new funkin.ui.freeplay.FreeplayAnimate(enterPos[0] + funkin.mobile.screen.WideScreen.offset, enterPos[1], enterImage, TOP_LEFT);
			var labels:Array<Array<Dynamic>> = [['idle', enterInfo.idle != null ? Std.string(enterInfo.idle) : 'Idle', true], ['press', enterInfo.press != null ? Std.string(enterInfo.press) : 'Confirm', false]];
			for (entry in labels)
			{
				var name:String = entry[0];
				var label:String = entry[1];
				var loop:Bool = entry[2];
				try
				{
					if (atlas.anim.getFrameLabel(label) != null) atlas.anim.addByFrameLabel(name, label, 24, loop);
				}
				catch (e:Dynamic) {}
			}
			atlas.anim.play('idle', true);
			titleAtlas = atlas;
			titleText = atlas;
		}
		else
		{
			var animFrames:Array<FlxFrame> = [];
			titleText = new FlxSprite(enterPos[0] + funkin.mobile.screen.WideScreen.offset, enterPos[1]);
			loadFrames(titleText, enterInfo);
			@:privateAccess
			{
				titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
				titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
			}

			if (newTitle = animFrames.length > 0)
			{
				titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
				titleText.animation.addByPrefix('press', Save.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
			}
			else
			{
				titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
				titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
			}
			titleText.animation.play('idle');
			titleText.updateHitbox();
		}
		if (swagShader != null) titleText.shader = swagShader.shader;
		titleText.visible = menu.visible('enter');

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		if (DataUtil.toBool(menu.data.logoOnTop))
		{
			add(gfDance);
			add(logoBl);
		}
		else
		{
			add(logoBl);
			add(gfDance);
		}
		add(titleText);

		var front:FlxSpriteGroup = new FlxSpriteGroup();
		menu.createSprites(front, null, true, variables);
		add(front);

		add(credGroup);
		for (info in menu.list('introSprites'))
		{
			var sprite:FlxSprite = funkin.data.ui.UIData.createSprite(info);
			if (sprite == null) continue;
			sprite.visible = false;
			if (info.name != null) introSprites.set(Std.string(info.name), sprite);
			add(sprite);
		}
		ngSpr = introSprites.get('newgrounds');
		for (info in menu.list('introSprites'))
			if (info != null && info.name == 'newgrounds' && DataUtil.toBool(info.randomVariants) && ngSpr != null)
				randomizeNewgrounds(ngSpr);

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	function randomizeNewgrounds(sprite:FlxSprite)
	{
		var baseY:Float = sprite.y;
		if (FlxG.random.bool(1) && Paths.fileExists('images/newgrounds_logo_classic.png', IMAGE))
		{
			sprite.loadGraphic(Paths.image('newgrounds_logo_classic'));
			sprite.scale.set(1, 1);
		}
		else if (FlxG.random.bool(30) && Paths.fileExists('images/newgrounds_logo_animated.png', IMAGE))
		{
			sprite.loadGraphic(Paths.image('newgrounds_logo_animated'), true, 600);
			sprite.animation.add('idle', [0, 1], 4);
			sprite.animation.play('idle');
			sprite.setGraphicSize(Std.int(sprite.width * 0.55));
			sprite.y = baseY + 25;
		}
		else return;
		sprite.updateHitbox();
		sprite.screenCenter(X);
	}

	function loadFrames(sprite:FlxSprite, info:Dynamic)
	{
		var render:Dynamic = info.render != null ? info.render : info;
		var image:String = funkin.graphics.FrameLoader.joinImages(render.image);
		var type:String = funkin.graphics.FrameLoader.resolveType(image, render.type);
		if (!funkin.graphics.FrameLoader.apply(sprite, image, type, DataUtil.intVector(render.frameSize)))
			sprite.frames = Paths.getSparrowAtlas(image);
		var scale:Array<Float> = DataUtil.vector(info.scale, 1, 1);
		sprite.scale.set(scale[0], scale[1]);
		sprite.updateHitbox();
		sprite.antialiasing = info.antialiasing != false && Save.data.antialiasing;
	}

	function addAnim(sprite:FlxSprite, name:String, prefix:String, indices:Array<Int>, fps:Float, loop:Bool)
	{
		if (indices != null && indices.length > 0) sprite.animation.addByIndices(name, prefix, indices, '', fps, loop);
		else sprite.animation.addByPrefix(name, prefix, fps, loop);
	}

	var useIdle:Bool = false;

	function loadJsonData()
	{
		menu = funkin.data.menu.MenuData.load('title', defaultData());

		if(!funkin.data.menu.MenuData.exists('title') && Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					var character:Dynamic = menu.element('character');
					character.position = [titleJSON.gfx, titleJSON.gfy];
					menu.element('logo').position = [titleJSON.titlex, titleJSON.titley];
					menu.element('enter').position = [titleJSON.startx, titleJSON.starty];
					menu.element('music').bpm = titleJSON.bpm;
					if(titleJSON.animation != null && titleJSON.animation.length > 0) character.animation = titleJSON.animation;
					if(titleJSON.dance_left != null && titleJSON.dance_left.length > 0) character.danceLeft = titleJSON.dance_left;
					if(titleJSON.dance_right != null && titleJSON.dance_right.length > 0) character.danceRight = titleJSON.dance_right;
					character.idle = titleJSON.idle == true;
					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
						menu.element('background').image = titleJSON.backgroundSprite;
				}
				catch(e:haxe.Exception) {}
			}
		}
	}

	function easterEggData()
	{
		if (Save.main.data.psychDevsEasterEgg == null) Save.main.data.psychDevsEasterEgg = '';
		var easterEgg:String = Save.main.data.psychDevsEasterEgg;
		var character:Dynamic = menu.element('character');
		var pos:Array<Float> = menu.position('character');
		function apply(image:String, animation:String, offsetX:Float, offsetY:Float, idle:Bool, ?left:Array<Int>, ?right:Array<Int>)
		{
			character.render = {type: 'sparrow', image: image};
			character.animation = animation;
			character.position = [pos[0] + offsetX, pos[1] + offsetY];
			character.idle = idle;
			if (left != null) character.danceLeft = left;
			if (right != null) character.danceRight = right;
		}
		switch(easterEgg.toUpperCase())
		{
			case 'SHADOW':
				apply('ShadowBump', 'Shadow Title Bump', 210, 40, true);
			case 'RIVEREN':
				apply('ZRiverBump', 'River Title Bump', 180, 40, true);
			case 'BBPANZU':
				apply('BBBump', 'BB Title Bump', 45, 100, false, [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
			case 'PESSY':
				apply('PessyBump', 'Pessy Title Bump', 165, 60, false, [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]);
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var file:String = 'data/introText.txt';
		var data:Dynamic = funkin.data.menu.MenuData.load('title', defaultData()).data;
		if (data.introTexts != null) file = Std.string(data.introTexts);
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed(file);
		#else
		var firstArray:Array<String> = Assets.getText(Paths.getPath(file, TEXT)).split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];
		for (i in firstArray)
			if (i.trim().length > 0) swagGoodArray.push(i.split('--'));
		if (swagGoodArray.length < 1) swagGoodArray.push(['', '']);
		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if (titleAtlas != null) titleAtlas.anim.play('press', true);
				else if (titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(Save.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, menu.float('confirm', 'flash', 1));
				FunkinSound.playOnce(menu.string('confirm', 'sound', 'confirmMenu'), menu.float('confirm', 'volume', 0.7));

				transitioning = true;

				new FlxTimer().start(menu.float('confirm', 'delay', 1), function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if(allowedKeys.contains(keyName)) {
					easterEggKeysBuffer += keyName;
					if(easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase();
						if (easterEggKeysBuffer.contains(word))
						{
							if (Save.main.data.psychDevsEasterEgg == word)
								Save.main.data.psychDevsEasterEgg = '';
							else
								Save.main.data.psychDevsEasterEgg = word;
							Save.flush();

							FunkinSound.playOnce('secret');

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
							black.scale.set(FlxG.width, FlxG.height);
							black.updateHitbox();
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween) {
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							if(FreeplayState.vocals != null)
							{
								FreeplayState.vocals.fadeOut();
							}
							closedState = true;
							transitioning = true;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		if (!cheatActive && skippedIntro && !transitioning) cheatCodeInput();

		#if desktop
		if (FlxG.keys.justPressed.Y)
		{
			FlxTween.cancelTweensOf(FlxG.stage.window, ['x', 'y']);
			FlxTween.tween(FlxG.stage.window, {x: FlxG.stage.window.x + 300}, 1.4, {ease: FlxEase.quadInOut, type: PINGPONG, startDelay: 0.35});
			FlxTween.tween(FlxG.stage.window, {y: FlxG.stage.window.y + 100}, 0.7, {ease: FlxEase.quadInOut, type: PINGPONG});
		}
		#end

		super.update(elapsed);
	}

	static final CHEAT_CODE:Array<Int> = [1, 1, 0, 0, 2, 3, 2, 3];
	var cheatPosition:Int = 0;
	var cheatActive:Bool = false;

	function cheatCodeInput()
	{
		var input:Int = -1;
		if (controls.UI_UP_P || controls.NOTE_UP_P) input = 0;
		else if (controls.UI_DOWN_P || controls.NOTE_DOWN_P) input = 1;
		else if (controls.UI_LEFT_P || controls.NOTE_LEFT_P) input = 2;
		else if (controls.UI_RIGHT_P || controls.NOTE_RIGHT_P) input = 3;
		if (input < 0) return;

		if (input == CHEAT_CODE[cheatPosition])
		{
			cheatPosition++;
			if (cheatPosition >= CHEAT_CODE.length)
			{
				cheatActive = true;
				FunkinSound.playMusic('girlfriendsRingtone/girlfriendsRingtone', 0);
				if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(4, 0, 1);
				FlxG.camera.flash(FlxColor.WHITE, 1);
				FunkinSound.playOnce('confirmMenu', 0.7);
			}
		}
		else cheatPosition = input == CHEAT_CODE[0] ? 1 : 0;
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if (cheatActive && curBeat % 2 == 0 && swagShader != null) swagShader.hue += 0.125;

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null)
		{
			danceLeft = !danceLeft;
			if(!useIdle)
			{
				if (danceLeft)
					gfDance.animation.play('danceRight');
				else
					gfDance.animation.play('danceLeft');
			}
			else if(curBeat % 2 == 0) gfDance.animation.play('idle', true);
		}

		if(!closedState)
		{
			sickBeats++;
			if (sickBeats == 1)
			{
				FunkinSound.playMusic(menu.string('music', 'name', 'freakyMenu'), 0);
				FlxG.sound.music.fadeIn(menu.float('music', 'fadeIn', 4), 0, menu.float('music', 'volume', 0.7));
			}
			for (entry in menu.list('intro'))
				if (entry != null && DataUtil.toInt(entry.beat, -1) == sickBeats)
					runIntroEntry(entry);
		}
	}

	function runIntroEntry(entry:Dynamic)
	{
		var lines:Array<String> = [];
		var raw:Array<Dynamic> = entry.text != null ? (Std.isOfType(entry.text, Array) ? entry.text : [entry.text]) : [];
		for (line in raw)
		{
			var text:String = Std.string(line);
			for (i in 0...curWacky.length) text = text.replace('{wacky$i}', curWacky[i]);
			lines.push(text);
		}
		var offset:Float = DataUtil.toFloat(entry.offset, 0);
		switch (Std.string(entry.action).toLowerCase())
		{
			case 'create':
				deleteCoolText();
				createCoolText(lines, offset);
			case 'add':
				for (line in lines) addMoreText(line, offset);
			case 'clear':
				deleteCoolText();
			case 'skip':
				skipIntro();
		}
		if (entry.show != null && introSprites.exists(Std.string(entry.show))) introSprites.get(Std.string(entry.show)).visible = true;
		if (entry.hide != null && introSprites.exists(Std.string(entry.hide))) introSprites.get(Std.string(entry.hide)).visible = false;
	}

	function removeIntroSprites()
	{
		for (sprite in introSprites) remove(sprite);
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			#if TITLE_SCREEN_EASTER_EGG
			if (playJingle)
			{
				playJingle = false;
				var easteregg:String = Save.main.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch(easteregg)
				{
					case 'RIVEREN':
						sound = FunkinSound.playOnce('JingleRiver');
					case 'SHADOW':
						FunkinSound.playOnce('JingleShadow');
					case 'BBPANZU':
						sound = FunkinSound.playOnce('JingleBB');
					case 'PESSY':
						sound = FunkinSound.playOnce('JinglePessy');

					default:
						removeIntroSprites();
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;

						FunkinSound.playMusic('freakyMenu', 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						return;
				}

				transitioning = true;
				if(easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						removeIntroSprites();
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					removeIntroSprites();
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function() {
						FunkinSound.playMusic('freakyMenu', 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
						#if ACHIEVEMENTS_ALLOWED
						if(easteregg == 'PESSY') Achievements.unlock('pessy_easter_egg');
						#end
					};
				}
			}
			else #end
			{
				removeIntroSprites();
				remove(credGroup);
				FlxG.camera.flash(funkin.data.ui.UIData.parseColor(menu.element('flash').color, FlxColor.WHITE), menu.float('flash', 'duration', 4));

				var easteregg:String = Save.main.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if(easteregg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
					if(FreeplayState.vocals != null)
					{
						FreeplayState.vocals.fadeOut();
					}
				}
				#end
			}
			skippedIntro = true;
		}
	}
}
