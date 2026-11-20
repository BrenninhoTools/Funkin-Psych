package funkin.ui.charSelect;

import flixel.FlxObject;
import funkin.graphics.LabelAnimate;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.freeplay.PixelatedIcon;
import openfl.display.BlendMode;

class CharSelectState extends MusicBeatState
{
	static inline var DEFAULT_CURSOR_INDEX:Int = 4;
	static inline var CURSOR_FACTOR:Float = 110;
	static inline var CURSOR_OFFSET_X:Float = -16;
	static inline var CURSOR_OFFSET_Y:Float = -48;
	static inline var GRID_SPREAD_X:Float = 107;
	static inline var GRID_SPREAD_Y:Float = 127;

	var rememberedChar:String;
	var curChar:String = null;
	var availableChars:Map<Int, String> = [];

	var cursorX:Int = 0;
	var cursorY:Int = 0;
	var cursors:CharSelectCursors;
	var cursorTarget:FlxPoint = FlxPoint.get();

	var playerChill:LabelAnimate;
	var gfChill:LabelAnimate;
	var currentGF:String = null;
	var nametag:FlxSprite;
	var nametagMid:FlxPoint = FlxPoint.get(1008, 100);
	var grpIcons:Array<FlxSprite> = [];
	var hitboxes:Array<FlxObject> = [];
	var barThing:LabelAnimate;
	var dipshitBacking:FlxSprite;
	var chooseDipshit:FlxSprite;
	var dipshitBlur:FlxSprite;
	var transitionGradient:FlxSprite;
	var camFollow:FlxObject;
	var charHitbox:FlxObject;

	var selectSound:FlxSound;
	var lockedSound:FlxSound;
	var allowInput:Bool = false;
	var pressedSelect:Bool = false;
	var selectTimer:FlxTimer = new FlxTimer();
	var autoFollow:Bool = false;

	public function new(?character:String)
	{
		super();
		rememberedChar = character != null ? character : PlayerData.DEFAULT;
	}

	override function create()
	{
		FlxTransitionableState.skipNextTransOut = true;
		PlayerData.reload();
		for (id in PlayerData.list())
		{
			var data:Dynamic = PlayerData.charSelect(id);
			if (data == null) continue;
			var position:Int = data.position != null ? Std.int(data.position) : 0;
			while (availableChars.exists(position)) position++;
			availableChars.set(position, id);
		}

		var bg:FlxSprite = new FlxSprite(-153, -140).loadGraphic(Paths.image('charSelect/charSelectBG'));
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		var crowd:LabelAnimate = new LabelAnimate(0, 0, 'charSelect/crowd');
		crowd.playTimeline();
		crowd.scrollFactor.set(0.3, 0.3);
		add(crowd);

		var stage:LabelAnimate = new LabelAnimate(-2, 1, 'charSelect/charSelectStage');
		stage.playTimeline();
		add(stage);

		var curtains:FlxSprite = new FlxSprite(-212, -99).loadGraphic(Paths.image('charSelect/curtains'));
		curtains.scrollFactor.set(1.4, 1.4);
		add(curtains);

		barThing = new LabelAnimate(0, 80, 'charSelect/barThing');
		barThing.playTimeline();
		barThing.blend = BlendMode.MULTIPLY;
		barThing.scale.x = 2.5;
		barThing.scrollFactor.set();
		add(barThing);
		FlxTween.tween(barThing, {y: 0}, 1.3, {ease: FlxEase.expoOut});

		add(new FlxSprite(800, 250).loadGraphic(Paths.image('charSelect/charLight')));
		add(new FlxSprite(180, 240).loadGraphic(Paths.image('charSelect/charLight')));

		gfChill = new LabelAnimate();
		gfChill.onLabelFinish = function(name:String)
		{
			if (name == 'deselect') gfChill.playLabel('idle', true, true);
		};
		add(gfChill);

		playerChill = new LabelAnimate();
		playerChill.onLabelFinish = onPlayerFinish;
		add(playerChill);

		var speakers:LabelAnimate = new LabelAnimate(-10, 0, 'charSelect/charSelectSpeakers');
		speakers.playTimeline();
		speakers.scrollFactor.set(1.8, 1.8);
		speakers.scale.set(1.05, 1.05);
		add(speakers);

		var fgBlur:FlxSprite = new FlxSprite(-125, 170).loadGraphic(Paths.image('charSelect/foregroundBlur'));
		fgBlur.blend = BlendMode.MULTIPLY;
		add(fgBlur);

		dipshitBlur = new FlxSprite(419, -65 + 220);
		dipshitBlur.frames = Paths.getSparrowAtlas('charSelect/dipshitBlur');
		dipshitBlur.animation.addByPrefix('idle', 'CHOOSE vertical offset instance 1', 24, true);
		dipshitBlur.animation.play('idle');
		dipshitBlur.blend = BlendMode.ADD;
		dipshitBlur.scrollFactor.set();
		add(dipshitBlur);
		FlxTween.tween(dipshitBlur, {y: -65}, 1.2, {ease: FlxEase.expoOut});

		dipshitBacking = new FlxSprite(423, -17 + 210);
		dipshitBacking.frames = Paths.getSparrowAtlas('charSelect/dipshitBacking');
		dipshitBacking.animation.addByPrefix('idle', 'CHOOSE horizontal offset instance 1', 24, true);
		dipshitBacking.animation.play('idle');
		dipshitBacking.blend = BlendMode.ADD;
		dipshitBacking.scrollFactor.set();
		add(dipshitBacking);
		FlxTween.tween(dipshitBacking, {y: -17}, 1.1, {ease: FlxEase.expoOut});

		chooseDipshit = new FlxSprite(426, -13 + 200).loadGraphic(Paths.image('charSelect/chooseDipshit'));
		chooseDipshit.scrollFactor.set();
		add(chooseDipshit);
		FlxTween.tween(chooseDipshit, {y: -13}, 1, {ease: FlxEase.expoOut});

		nametag = new FlxSprite();
		nametag.scrollFactor.set();
		add(nametag);
		nametagMid.y += 200;
		FlxTween.tween(nametagMid, {y: 100}, 1, {ease: FlxEase.expoOut});

		initIcons();

		cursors = new CharSelectCursors();
		add(cursors);

		charHitbox = new FlxObject(FlxG.width * 0.65, FlxG.height * 0.2, 300, 500);

		transitionGradient = new FlxSprite().loadGraphic(Paths.image('freeplay/transitionGradient'));
		transitionGradient.scale.set(FlxG.width, 1);
		transitionGradient.flipY = true;
		transitionGradient.updateHitbox();
		transitionGradient.scrollFactor.set();
		add(transitionGradient);
		FlxTween.tween(transitionGradient, {y: -720}, 1, {ease: FlxEase.expoOut});

		for (member in members)
			if (Std.isOfType(member, FlxSprite)) cast(member, FlxSprite).antialiasing = Save.data.antialiasing;

		var startIndex:Int = DEFAULT_CURSOR_INDEX;
		for (position => id in availableChars)
			if (id == rememberedChar) startIndex = position;
		cursorX = (startIndex % 3) - 1;
		cursorY = Math.floor(startIndex / 3) - 1;
		updateCursorTarget();
		cursors.snapToLocation(cursorTarget);
		applySelection(false);

		selectSound = FlxG.sound.load(Paths.sound('CS_select'), 0.7);
		lockedSound = FlxG.sound.load(Paths.sound('CS_locked'));

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.screenCenter();
		camFollow.y -= 150;
		add(camFollow);
		FlxG.camera.follow(camFollow, LOCKON);
		FlxG.camera.snapToTarget();
		FlxTween.tween(camFollow, {y: camFollow.y + 150}, 1.5, {
			ease: FlxEase.expoOut,
			onComplete: function(_)
			{
				autoFollow = true;
				FlxG.camera.follow(camFollow, LOCKON, 0.01);
			}
		});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, true);

		FunkinSound.playMusic('stayFunky/stayFunky', 0);
		if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(1, 0, 1);
		Conductor.bpm = 90;
		new FlxTimer().start(0.6, function(_) allowInput = true);

		#if mobile
		add(funkin.mobile.controls.MobileButton.back());
		#end

		super.create();
	}

	function initIcons()
	{
		for (i in 0...9)
		{
			var id:String = availableChars.get(i);
			var sprite:FlxSprite;
			if (id != null && PlayerData.isUnlocked(id))
			{
				var icon:PixelatedIcon = new PixelatedIcon(0, 0);
				icon.setCharacter(id);
				icon.setGraphicSize(128, 128);
				icon.updateHitbox();
				sprite = icon;
			}
			else
			{
				var lock:LabelAnimate = new LabelAnimate(0, 0, 'charSelect/lock', false);
				lock.offset.set(230, 110);
				lock.playLabel('idle', true, true);
				sprite = lock;
			}
			sprite.scrollFactor.set();
			sprite.x = 450 + (i % 3) * GRID_SPREAD_X;
			sprite.y = 120 + Math.floor(i / 3) * GRID_SPREAD_Y + 300;
			FlxTween.tween(sprite, {y: sprite.y - 300}, 1, {ease: FlxEase.expoOut});
			add(sprite);
			grpIcons.push(sprite);

			var hitbox:FlxObject = new FlxObject(450 + (i % 3) * GRID_SPREAD_X + 20, 120 + Math.floor(i / 3) * GRID_SPREAD_Y + 20, 86, 86);
			hitbox.scrollFactor.set();
			hitboxes.push(hitbox);
		}
	}

	inline function currentIndex():Int
		return (cursorX + 1) + (cursorY + 1) * 3;

	function updateCursorTarget()
	{
		cursorTarget.x = (CURSOR_FACTOR * cursorX) + (FlxG.width / 2) - cursors.main.width / 2 + CURSOR_OFFSET_X;
		cursorTarget.y = (CURSOR_FACTOR * cursorY) + (FlxG.height / 2) - cursors.main.height / 2 + CURSOR_OFFSET_Y;
	}

	function applySelection(slide:Bool = true)
	{
		var id:String = availableChars.get(currentIndex());
		var unlocked:Bool = id != null && PlayerData.isUnlocked(id);
		var target:String = unlocked ? id : 'locked';
		if (target == curChar) return;
		curChar = target;

		playerChill.loadFolder('charSelect/${unlocked ? id : 'locked'}Chill', unlocked);
		playerChill.setPosition(0, 0);
		if (!playerChill.playLabel(slide ? 'slidein' : 'idle', true, !slide)) playerChill.playLabel('idle', true, true);

		var gfPath:String = null;
		if (unlocked)
		{
			var data:Dynamic = PlayerData.charSelect(id);
			if (data != null && data.gf != null && data.gf.assetPath != null) gfPath = Std.string(data.gf.assetPath);
		}
		gfChill.visible = gfPath != null;
		if (gfPath != null && gfPath != currentGF)
		{
			currentGF = gfPath;
			gfChill.loadFolder(gfPath, true);
			gfChill.setPosition(0, 0);
		}
		if (gfPath != null) gfChill.playLabel('idle', true, true);

		var tag:String = unlocked ? (id == 'bf' ? 'boyfriend' : id) : 'locked';
		if (!Paths.fileExists('images/charSelect/${tag}Nametag.png', IMAGE)) tag = 'locked';
		nametag.loadGraphic(Paths.image('charSelect/${tag}Nametag'));
		nametag.scale.set(0.77, 0.77);
		nametag.updateHitbox();
	}

	function onPlayerFinish(name:String)
	{
		switch (name)
		{
			case 'slidein':
				if (!playerChill.playLabel('slidein idle point')) playerChill.playLabel('idle', true, true);
			case 'deselect':
				if (!playerChill.playLabel('deselect loop start', true, true)) playerChill.playLabel('idle', true, true);
			case 'slidein idle point', 'cannot select Label', 'unlock':
				playerChill.playLabel('idle', true, true);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.sound.music != null && FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;

		nametag.x = nametagMid.x - nametag.width / 2;
		nametag.y = nametagMid.y - nametag.height / 2;

		var mobileAccept:Bool = false;
		if (allowInput && !pressedSelect)
		{
			#if mobile
			if (funkin.mobile.input.TouchInput.justTapped())
			{
				var tapX:Float = funkin.mobile.input.TouchInput.tapX;
				var tapY:Float = funkin.mobile.input.TouchInput.tapY;
				for (i => hitbox in hitboxes)
				{
					if (!funkin.mobile.input.TouchInput.overlapsScreen(hitbox, tapX, tapY)) continue;
					var cx:Int = (i % 3) - 1;
					var cy:Int = Math.floor(i / 3) - 1;
					if (cx != cursorX || cy != cursorY)
					{
						cursorX = cx;
						cursorY = cy;
						moved();
					}
					else mobileAccept = true;
					break;
				}
				if (funkin.mobile.input.TouchInput.overlapsScreen(charHitbox, tapX, tapY)) mobileAccept = true;
			}
			#end

			if (controls.UI_UP_P)
			{
				cursorY--;
				moved();
			}
			if (controls.UI_DOWN_P)
			{
				cursorY++;
				moved();
			}
			if (controls.UI_LEFT_P)
			{
				cursorX--;
				moved();
			}
			if (controls.UI_RIGHT_P)
			{
				cursorX++;
				moved();
			}
			cursorX = FlxMath.wrap(cursorX, -1, 1);
			cursorY = FlxMath.wrap(cursorY, -1, 1);
			applySelection();

			if (controls.BACK)
			{
				FunkinSound.playOnce('cancelMenu');
				if (FlxG.sound.music != null) FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.7, {ease: FlxEase.quadInOut});
				goToFreeplay(rememberedChar);
				return;
			}
			if (controls.ACCEPT || mobileAccept) accept();
		}
		else if (allowInput && pressedSelect && controls.BACK) deselect();

		if (autoFollow)
		{
			camFollow.screenCenter();
			camFollow.x += cursorX * 10;
			camFollow.y += cursorY * 10;
		}
		updateCursorTarget();
		cursors.lerpToLocation(cursorTarget);
	}

	function moved()
	{
		cursors.resetDeny();
		if (selectSound != null) selectSound.play(true);
	}

	function accept()
	{
		if (curChar == 'locked')
		{
			playerChill.playLabel('cannot select Label', true);
			if (lockedSound != null) lockedSound.play(true);
			cursors.deny();
			return;
		}

		pressedSelect = true;
		cursors.confirm();
		FunkinSound.playOnce('CS_confirm');
		if (FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxTween.tween(FlxG.sound.music, {pitch: 0.1}, 1, {ease: FlxEase.quadInOut});
			FlxTween.tween(FlxG.sound.music, {volume: 0.0}, 1.5, {ease: FlxEase.quadInOut});
		}
		playerChill.playLabel('select', true);
		gfChill.playLabel('confirm', true, true);
		var chosen:String = curChar;
		selectTimer.start(1.5, function(_) goToFreeplay(chosen));
	}

	function deselect()
	{
		selectTimer.cancel();
		pressedSelect = false;
		cursors.unconfirm();
		if (FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxTween.tween(FlxG.sound.music, {pitch: 1.0, volume: 1.0}, 1, {ease: FlxEase.quartInOut});
		}
		playerChill.playLabel('deselect', true);
		gfChill.playLabel('deselect', true);
	}

	function goToFreeplay(character:String)
	{
		allowInput = false;
		autoFollow = false;
		FlxTween.tween(cursors, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});
		FlxTween.tween(barThing, {y: barThing.y + 80}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(nametagMid, {y: nametagMid.y + 80}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(dipshitBacking, {y: dipshitBacking.y + 210}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(chooseDipshit, {y: chooseDipshit.y + 200}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(dipshitBlur, {y: dipshitBlur.y + 220}, 0.8, {ease: FlxEase.backIn});
		for (icon in grpIcons) FlxTween.tween(icon, {y: icon.y + 300}, 0.8, {ease: FlxEase.backIn});
		FlxTween.cancelTweensOf(transitionGradient);
		FlxTween.tween(transitionGradient, {y: -150}, 0.8, {ease: FlxEase.backIn});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
		FlxTween.tween(camFollow, {y: camFollow.y - 150}, 0.8, {
			ease: FlxEase.backIn,
			onComplete: function(_)
			{
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.pitch = 1;
					FlxG.sound.music.stop();
				}
				FreeplayState.currentCharacter = character;
				FlxTransitionableState.skipNextTransIn = true;
				MusicBeatState.switchState(new FreeplayState());
			}
		});
	}

	override function destroy()
	{
		cursorTarget = flixel.util.FlxDestroyUtil.put(cursorTarget);
		nametagMid = flixel.util.FlxDestroyUtil.put(nametagMid);
		super.destroy();
	}
}

class CharSelectCursors extends FlxSpriteGroup
{
	public var main:FlxSprite;

	var lightBlue:FlxSprite;
	var darkBlue:FlxSprite;
	var confirmed:FlxSprite;
	var denied:FlxSprite;

	public function new()
	{
		super();
		darkBlue = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		lightBlue = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		main = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		darkBlue.color = 0xFF3C74F7;
		lightBlue.color = 0xFF3EBBFF;
		main.color = 0xFFFFFF00;
		FlxTween.color(main, 0.2, 0xFFFFFF00, 0xFFFFCC00, {type: PINGPONG});
		darkBlue.blend = BlendMode.SCREEN;
		lightBlue.blend = BlendMode.SCREEN;
		add(darkBlue);
		add(lightBlue);
		add(main);

		confirmed = new FlxSprite();
		confirmed.frames = Paths.getSparrowAtlas('charSelect/charSelectorConfirm');
		confirmed.animation.addByPrefix('idle', 'cursor ACCEPTED instance 1', 24, true);
		confirmed.visible = false;
		add(confirmed);

		denied = new FlxSprite();
		denied.frames = Paths.getSparrowAtlas('charSelect/charSelectorDenied');
		denied.animation.addByPrefix('idle', 'cursor DENIED instance 1', 24, false);
		denied.animation.onFinish.add(function(_) denied.visible = false);
		denied.visible = false;
		add(denied);

		for (member in members) member.antialiasing = Save.data.antialiasing;
		scrollFactor.set();
	}

	public function confirm()
	{
		confirmed.visible = true;
		confirmed.animation.play('idle', true);
		main.visible = lightBlue.visible = darkBlue.visible = false;
	}

	public function unconfirm()
	{
		confirmed.visible = false;
		main.visible = lightBlue.visible = darkBlue.visible = true;
	}

	public function deny()
	{
		denied.visible = true;
		denied.animation.play('idle', true);
	}

	public function resetDeny()
		denied.visible = false;

	public function snapToLocation(target:FlxPoint)
	{
		main.setPosition(target.x, target.y);
		lightBlue.setPosition(target.x, target.y);
		darkBlue.setPosition(target.x, target.y);
		syncExtras();
	}

	public function lerpToLocation(target:FlxPoint)
	{
		var elapsed:Float = FlxG.elapsed;
		main.x = MathUtil.smoothLerpPrecision(main.x, target.x, elapsed, 0.1);
		main.y = MathUtil.smoothLerpPrecision(main.y, target.y, elapsed, 0.1);
		if (Math.abs(main.x - target.x) < 1) main.x = target.x;
		if (Math.abs(main.y - target.y) < 1) main.y = target.y;
		lightBlue.x = MathUtil.smoothLerpPrecision(lightBlue.x, main.x, elapsed, 0.202);
		lightBlue.y = MathUtil.smoothLerpPrecision(lightBlue.y, main.y, elapsed, 0.202);
		darkBlue.x = MathUtil.smoothLerpPrecision(darkBlue.x, target.x, elapsed, 0.404);
		darkBlue.y = MathUtil.smoothLerpPrecision(darkBlue.y, target.y, elapsed, 0.404);
		syncExtras();
	}

	function syncExtras()
	{
		confirmed.setPosition(main.x - 2, main.y - 4);
		denied.setPosition(main.x - 2, main.y - 4);
	}
}
