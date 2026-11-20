package funkin.ui.freeplay;

import flixel.FlxObject;
import flixel.addons.effects.FlxTrail;
import openfl.display.BlendMode;

class SongMenuItem extends FlxSpriteGroup
{
	static final X_FRAMES:Array<Float> = [1.7, 1.8, 0.85, 0.85, 0.97, 0.97, 1];
	static final X_POS_LERP:Array<Float> = [0, 0, 0.16, 0.16, 0.22, 0.22, 0.245];
	static final X_POS_OUT_LERP:Array<Float> = [0.245, 0.75, 0.98, 0.98, 1.2];

	public var capsule:FlxSprite;
	public var freeplayData(default, null):FreeplaySongData = null;
	public var selected(default, set):Bool = false;
	public var forceHighlight(default, set):Bool = false;
	public var favIcon:FlxSprite;
	public var favIconBlurred:FlxSprite;
	public var ranking:FreeplayRank;
	public var blurredRanking:FreeplayRank;
	public var targetPos:FlxPoint = new FlxPoint();
	public var doLerp:Bool = false;
	public var doJumpIn:Bool = false;
	public var doJumpOut:Bool = false;
	public var onConfirm:Void->Void;
	public var bpmText:FlxSprite;
	public var difficultyText:FlxSprite;
	public var newText:FlxSprite;
	public var sparkle:FlxSprite;
	public var hitbox:FlxObject;
	public var realScaled:Float = 0.8;
	public var curSelected:Int = 0;
	public var index:Int = 0;
	public var cutoutOffset:Float = 0;

	var pixelIcon:PixelatedIcon;
	var songText:CapsuleText;
	var difficultyNumbers:Array<CapsuleNumber> = [];
	var bpmNumbers:Array<CapsuleNumber> = [];
	var grpHide:Array<FlxSprite> = [];
	var sparkleTimer:FlxTimer;
	var impactThing:FlxSprite;
	var evilTrail:FlxTrail;
	var frameInTicker:Float = 0;
	var frameInTypeBeat:Int = 0;
	var frameOutTicker:Float = 0;
	var frameOutTypeBeat:Int = 0;

	public function new(x:Float, y:Float, capsuleAsset:String)
	{
		super(x, y);

		capsule = new FlxSprite();
		capsule.frames = Paths.getSparrowAtlas(capsuleAsset);
		capsule.animation.addByPrefix('selected', 'mp3 capsule w backing0', 24);
		capsule.animation.addByPrefix('unselected', 'mp3 capsule w backing NOT SELECTED', 24);
		capsule.animation.play('selected');
		add(capsule);

		bpmText = new FlxSprite(144, 87).loadGraphic(Paths.image('freeplay/freeplayCapsule/bpmtext'));
		bpmText.setGraphicSize(Std.int(bpmText.width * 0.9));
		add(bpmText);

		difficultyText = new FlxSprite(414, 87).loadGraphic(Paths.image('freeplay/freeplayCapsule/difficultytext'));
		difficultyText.setGraphicSize(Std.int(difficultyText.width * 0.9));
		add(difficultyText);

		newText = new FlxSprite(454, 9);
		newText.frames = Paths.getSparrowAtlas('freeplay/freeplayCapsule/new');
		newText.animation.addByPrefix('newAnim', 'NEW notif', 24, true);
		newText.animation.play('newAnim', true);
		newText.setGraphicSize(Std.int(newText.width * 0.9));
		newText.visible = false;
		add(newText);

		for (i in 0...2)
		{
			var num:CapsuleNumber = new CapsuleNumber(466 + (i * 30), 32, true, 0);
			add(num);
			difficultyNumbers.push(num);
		}

		for (i in 0...3)
		{
			var num:CapsuleNumber = new CapsuleNumber(185 + (i * 11), 88.5, false, 0);
			add(num);
			bpmNumbers.push(num);
		}

		ranking = new FreeplayRank(420, 41);
		add(ranking);
		blurredRanking = new FreeplayRank(ranking.x, ranking.y);
		add(blurredRanking);

		sparkle = new FlxSprite(ranking.x, ranking.y);
		sparkle.frames = Paths.getSparrowAtlas('freeplay/sparkle');
		sparkle.animation.addByPrefix('sparkle', 'sparkle Export0', 24, false);
		sparkle.animation.play('sparkle', true);
		sparkle.scale.set(0.8, 0.8);
		sparkle.blend = BlendMode.ADD;
		sparkle.visible = false;
		sparkle.alpha = 0.7;
		add(sparkle);

		songText = new CapsuleText(capsule.width * 0.26, 45, 'Random', Std.int(40 * realScaled));
		add(songText);
		grpHide.push(songText);

		pixelIcon = new PixelatedIcon(160, 35);
		add(pixelIcon);
		grpHide.push(pixelIcon);

		favIconBlurred = makeHeart();
		favIconBlurred.blend = BlendMode.ADD;
		add(favIconBlurred);
		favIcon = makeHeart();
		favIcon.blend = BlendMode.ADD;
		add(favIcon);

		for (member in members)
			if (member != pixelIcon && member != null) member.antialiasing = Save.data.antialiasing;

		setVisibleGroup(false);
		hitbox = new FlxObject(capsule.x + 160, capsule.y - 20, Math.round(capsule.width / 1.4), Math.round(capsule.height / 1.4));
		hitbox.active = false;
	}

	function makeHeart():FlxSprite
	{
		var heart:FlxSprite = new FlxSprite(380, 40);
		heart.frames = Paths.getSparrowAtlas('freeplay/favHeart');
		heart.animation.addByPrefix('fav', 'favorite heart', 24, false);
		heart.animation.play('fav');
		heart.setGraphicSize(50, 50);
		heart.visible = false;
		return heart;
	}

	public function applyStyle(textColor:FlxColor)
		songText.applyStyle(textColor);

	function sparkleEffect(_):Void
	{
		sparkle.setPosition(FlxG.random.float(ranking.x - 20, ranking.x + 3), FlxG.random.float(ranking.y - 29, ranking.y + 4));
		sparkle.animation.play('sparkle', true);
		sparkleTimer = new FlxTimer().start(FlxG.random.float(1.2, 4.5), sparkleEffect);
	}

	public function checkClip():Void
	{
		var clipType:Int = 0;
		if (ranking.visible)
		{
			favIconBlurred.x = favIcon.x = x + 370;
			clipType++;
		}
		else favIconBlurred.x = favIcon.x = x + 405;
		if (favIcon.visible) clipType++;

		songText.clipWidth = switch (clipType)
		{
			case 2: 210;
			case 1: 245;
			default: 290;
		}
	}

	function updateBPM(newBPM:Int):Void
	{
		var shiftX:Float = Math.floor(newBPM / 100) == 1 ? 186 : 191;
		var tempShift:Float = 0;
		for (i in 0...bpmNumbers.length)
		{
			bpmNumbers[i].x = x + shiftX + (i * 11);
			switch (i)
			{
				case 0:
					bpmNumbers[i].digit = newBPM < 100 ? 0 : Math.floor(newBPM / 100) % 10;
				case 1:
					if (newBPM < 10) bpmNumbers[i].digit = 0;
					else
					{
						bpmNumbers[i].digit = Math.floor(newBPM / 10) % 10;
						if (Math.floor(newBPM / 10) % 10 == 1) tempShift = -4;
					}
				case 2:
					bpmNumbers[i].digit = newBPM % 10;
					if (newBPM % 10 == 1) tempShift -= 4;
			}
			bpmNumbers[i].x += tempShift;
		}
	}

	function updateDifficultyRating(rating:Int):Void
	{
		difficultyNumbers[0].digit = rating < 10 ? 0 : Math.floor(rating / 10);
		difficultyNumbers[1].digit = rating % 10;
	}

	function updateScoringRank(rank:Null<FreeplayRank.RankType>):Void
	{
		if (sparkleTimer != null) sparkleTimer.cancel();
		sparkle.visible = false;
		ranking.rank = rank;
		blurredRanking.rank = rank;
		if (rank == PERFECT_GOLD)
		{
			sparkleTimer = new FlxTimer().start(1, sparkleEffect);
			sparkle.visible = true;
		}
	}

	public function fadeAnim():Void
	{
		clearUpTrail();
		impactThing = new FlxSprite();
		impactThing.frames = capsule.frames;
		impactThing.frame = capsule.frame;
		impactThing.updateHitbox();
		impactThing.alpha = 0;
		insert(0, impactThing);
		FlxTween.tween(impactThing.scale, {x: 2.5, y: 2.5}, 0.5);

		evilTrail = new FlxTrail(impactThing, null, 15, 2, 0.01, 0.069);
		evilTrail.blend = BlendMode.ADD;
		evilTrail.color = FreeplayRank.colorOf(ranking.rank);
		insert(0, evilTrail);
		FlxTween.tween(evilTrail, {alpha: 0}, 0.6, {ease: FlxEase.quadOut, onComplete: function(_) clearUpTrail()});
	}

	function clearUpTrail()
	{
		if (impactThing != null)
		{
			FlxTween.cancelTweensOf(impactThing);
			FlxTween.cancelTweensOf(impactThing.scale);
			remove(impactThing, true);
			impactThing.destroy();
			impactThing = null;
		}
		if (evilTrail != null)
		{
			FlxTween.cancelTweensOf(evilTrail);
			remove(evilTrail, true);
			evilTrail.destroy();
			evilTrail = null;
		}
	}

	public function refreshDisplay(difficulty:String, updateRank:Bool = true):Void
	{
		if (freeplayData == null)
		{
			songText.text = 'Random';
			pixelIcon.visible = false;
			ranking.visible = blurredRanking.visible = false;
			favIcon.visible = favIconBlurred.visible = false;
			newText.visible = false;
			sparkle.visible = false;
		}
		else
		{
			songText.text = freeplayData.songName;
			pixelIcon.setCharacter(freeplayData.icon);
			updateBPM(Std.int(freeplayData.bpm));
			updateDifficultyRating(freeplayData.getRating(difficulty));
			if (updateRank) updateScoringRank(freeplayData.getRank(difficulty));
			favIcon.visible = favIconBlurred.visible = freeplayData.isFav;
			checkClip();
		}
		updateSelected();
	}

	public function setFavorite(value:Bool, animate:Bool = true)
	{
		favIcon.visible = favIconBlurred.visible = value;
		if (value && animate)
		{
			favIcon.animation.play('fav', true);
			favIconBlurred.animation.play('fav', true);
		}
		checkClip();
	}

	function textAppear():Void
	{
		songText.scale.set(1.7, 0.2);
		new FlxTimer().start(1 / 24, function(_)
		{
			songText.scale.set(0.4, 1.4);
			new FlxTimer().start(2 / 24, function(_) songText.scale.set(1, 1));
		});
	}

	function setVisibleGroup(value:Bool):Void
	{
		for (sprite in grpHide) sprite.visible = value;
		if (value && freeplayData != null && !pixelIcon.visible) pixelIcon.setCharacter(freeplayData.icon);
		if (freeplayData == null) pixelIcon.visible = false;
		textAppear();
		updateSelected();
	}

	public function initData(data:FreeplaySongData, index:Int, difficulty:String):Void
	{
		freeplayData = data;
		this.index = index;
		updateScoringRank(data != null ? data.getRank(difficulty) : null);
		favIcon.animation.curAnim.curFrame = favIcon.animation.curAnim.numFrames - 1;
		favIconBlurred.animation.curAnim.curFrame = favIconBlurred.animation.curAnim.numFrames - 1;
		refreshDisplay(difficulty);
	}

	public function initJumpIn(maxTimer:Float, force:Bool = false):Void
	{
		frameInTypeBeat = 0;
		new FlxTimer().start((1 / 24) * maxTimer, function(_)
		{
			doJumpIn = true;
			doLerp = true;
		});

		if (force)
		{
			visible = true;
			capsule.alpha = 1;
			setVisibleGroup(true);
		}
		else new FlxTimer().start((X_FRAMES.length / 24) * 2.5, function(_)
		{
			visible = true;
			capsule.alpha = 1;
			setVisibleGroup(true);
		});
	}

	public function forcePosition():Void
	{
		visible = true;
		capsule.alpha = 1;
		doLerp = true;
		doJumpIn = false;
		doJumpOut = false;
		frameInTypeBeat = X_FRAMES.length;
		frameOutTypeBeat = 0;
		capsule.scale.set(X_FRAMES[frameInTypeBeat - 1] * realScaled, (1 / X_FRAMES[frameInTypeBeat - 1]) * realScaled);
		x = targetPos.x;
		y = targetPos.y;
		setVisibleGroup(true);
	}

	override function update(elapsed:Float):Void
	{
		if (impactThing != null) impactThing.angle = capsule.angle;

		if (doJumpIn)
		{
			frameInTicker += elapsed;
			if (frameInTicker >= 1 / 24 && frameInTypeBeat < X_FRAMES.length)
			{
				frameInTicker = 0;
				capsule.scale.set(X_FRAMES[frameInTypeBeat] * realScaled, (1 / X_FRAMES[frameInTypeBeat]) * realScaled);
				targetPos.x = FlxG.width * X_POS_LERP[Std.int(Math.min(frameInTypeBeat, X_POS_LERP.length - 1))];
				frameInTypeBeat++;
				if (targetPos.x <= 320) targetPos.x = intendedX(index - curSelected) + cutoutOffset;
			}
			else if (frameInTypeBeat == X_FRAMES.length) doJumpIn = false;
		}

		if (doJumpOut)
		{
			frameOutTicker += elapsed;
			if (frameOutTicker >= 1 / 24 && frameOutTypeBeat < X_FRAMES.length)
			{
				frameOutTicker = 0;
				capsule.scale.set(X_FRAMES[frameOutTypeBeat] * realScaled, (1 / X_FRAMES[frameOutTypeBeat]) * realScaled);
				x = FlxG.width * X_POS_OUT_LERP[Std.int(Math.min(frameOutTypeBeat, X_POS_OUT_LERP.length - 1))];
				frameOutTypeBeat++;
			}
			else if (frameOutTypeBeat == X_FRAMES.length) doJumpOut = false;
		}

		if (doLerp)
		{
			x = MathUtil.smoothLerpPrecision(x, targetPos.x, elapsed, 0.256);
			y = MathUtil.smoothLerpPrecision(y, targetPos.y, elapsed, 0.192);
		}

		hitbox.x = x + 100;
		hitbox.y = y + 20;
		super.update(elapsed);
	}

	public function confirm():Void
	{
		textAppear();
		songText.flickerText();
		pixelIcon.confirm();
	}

	public inline function intendedX(position:Float):Float
		return 270 + (60 * FlxMath.fastSin(position));

	public inline function intendedY(position:Float):Float
		return (position * ((capsule.height * realScaled) + 10)) + 120;

	function set_selected(value:Bool):Bool
	{
		var changed:Bool = selected != value;
		selected = value;
		if (changed) updateSelected();
		return value;
	}

	function set_forceHighlight(value:Bool):Bool
	{
		forceHighlight = value;
		updateSelected();
		return value;
	}

	public function updateSelected():Void
	{
		if (songText == null) return;
		var isSelected:Bool = selected || forceHighlight;
		songText.alpha = isSelected ? 1 : 0.6;
		songText.blurredText.visible = isSelected;
		capsule.offset.x = isSelected ? 0 : -5;
		capsule.animation.play(isSelected ? 'selected' : 'unselected');
		ranking.alpha = isSelected ? 1 : 0.7;
		favIcon.alpha = isSelected ? 1 : 0.6;
		favIconBlurred.alpha = isSelected ? 1 : 0;
		ranking.color = isSelected ? 0xFFFFFFFF : 0xFFAAAAAA;
		if (songText.tooLong) songText.resetText();
		if (selected && songText.tooLong) songText.initMove();
	}

	override function destroy()
	{
		if (sparkleTimer != null) sparkleTimer.cancel();
		clearUpTrail();
		hitbox = flixel.util.FlxDestroyUtil.destroy(hitbox);
		targetPos = flixel.util.FlxDestroyUtil.put(targetPos);
		super.destroy();
	}
}
