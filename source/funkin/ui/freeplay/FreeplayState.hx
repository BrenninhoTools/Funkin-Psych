package funkin.ui.freeplay;

import flixel.FlxObject;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.util.FlxDestroyUtil;
import flixel.text.FlxText.FlxTextBorderStyle;
import funkin.data.song.Song;
import funkin.save.Highscore;
import funkin.shaders.AngleMask;
import funkin.shaders.StrokeShader;
import funkin.ui.freeplay.components.DifficultyDot;
import funkin.ui.freeplay.components.DifficultySelector;
import funkin.ui.freeplay.components.DifficultySprite;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.options.GameplayChangersSubstate;
import funkin.ui.story.StoryMenuState;
import haxe.Json;
import openfl.media.Sound;
#if mobile
import funkin.mobile.input.TouchInput;
#end

typedef MoveData =
{
	?x:Float,
	?y:Float,
	?speed:Float,
	?wait:Float
}

typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;

enum FreeplayUIState
{
	Entering;
	Idle;
	Interacting;
	Exiting;
}

class FreeplayState extends MusicBeatState
{
	public static inline var DJ_POS_MULTI:Float = 0.44;
	public static inline var SONGS_POS_MULTI:Float = 0.75;
	public static final DOTS_POS:Array<Float> = [260, 170];
	static inline var FADE_IN_DELAY:Float = 0.25;
	static inline var MAX_DOTS_PER_ROW:Int = 8;

	public static var currentCharacter:String = 'bf';
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	static var rememberedSong:String = null;
	static var rememberedDifficulty:String = null;
	static var rememberedFilter:String = 'ALL';

	public var backingImage:FlxSprite;
	public var angleMaskShader:AngleMask = new AngleMask();

	var uiState:FreeplayUIState = Entering;
	var cutoutWidth:Float = 0;
	var djOffset:Float = 0;
	var songsOffset:Float = 0;

	var songs:Array<FreeplaySongData> = [];
	var filteredSongs:Array<FreeplaySongData> = [];
	var allDifficulties:Array<String> = [];
	var currentDifficulty:String;
	var currentFilter:String = 'ALL';
	var curSelected:Int = 0;
	var curSelectedFloat:Float = 0;
	var currentCapsule(get, never):SongMenuItem;

	var style:Dynamic;
	var backingCard:BackingCard;
	var dj:FreeplayDJ;
	var albumRoll:AlbumRoll;
	var letterSort:LetterSort;
	var scoreDisplay:FreeplayScore;
	var completionText:CompletionText;
	var highscoreSprite:FlxSprite;
	var clearBox:FlxSprite;
	var blackOverlay:FlxSprite;
	var overhang:FlxSprite;
	var topLeftText:FlxText;
	var topLeftBg:FlxSprite;
	var ostName:FlxText;
	var hintText:FlxText;
	var titleStroke:StrokeShader;
	var missingText:FlxText;
	var missingBg:FlxSprite;

	var grpCapsules:FlxTypedGroup<SongMenuItem>;
	var grpDifficulties:FlxTypedSpriteGroup<DifficultySprite>;
	var difficultyDots:FlxTypedGroup<DifficultyDot>;
	var diffSelLeft:DifficultySelector;
	var diffSelRight:DifficultySelector;

	var exitMovers:ExitMoverData = new Map();
	var lerpScore:Float = 0;
	var intendedScore:Int = 0;
	var lerpCompletion:Float = 0;
	var intendedCompletion:Float = 0;
	var holdTime:Float = 0;
	var previewTimers:Array<FlxTimer> = [];
	var previewToken:Int = 0;
	var startingSong:Bool = false;
	var prevDotIndex:Int = -1;

	#if mobile
	var changersButton:funkin.mobile.controls.TouchButton;
	var resetButton:funkin.mobile.controls.TouchButton;
	var backButton:funkin.mobile.controls.MobileButton;
	var dragAccum:Float = 0;
	#end

	public static function destroyFreeplayVocals()
	{
		if (vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);
		if (opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		FlxTransitionableState.skipNextTransOut = true;
		LevelData.reloadLevelFiles(false);
		FreeplaySongData.reloadInfo();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('In the Menus', null);
		#end

		if (LevelData.levelsList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new funkin.ui.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new funkin.ui.debug.LevelEditorState()),
				function() MusicBeatState.switchState(new MainMenuState())));
			return;
		}

		loadSongs();
		loadStyle();

		cutoutWidth = Math.max(0, FlxG.width - 1280);
		djOffset = cutoutWidth * DJ_POS_MULTI;
		songsOffset = cutoutWidth * SONGS_POS_MULTI;

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		menuBG.antialiasing = Save.data.antialiasing;
		menuBG.setGraphicSize(FlxG.width + 1, 0);
		menuBG.updateHitbox();
		menuBG.screenCenter();
		add(menuBG);

		funkin.ui.charSelect.PlayerData.reload();
		if (!funkin.ui.charSelect.PlayerData.exists(currentCharacter)) currentCharacter = funkin.ui.charSelect.PlayerData.DEFAULT;
		var djData:Dynamic = funkin.ui.charSelect.PlayerData.freeplayDJ(currentCharacter);
		if (djData == null) djData = FreeplayDJ.loadData('bf');
		var djTexts:Array<String> = null;
		if (djData != null)
		{
			dj = new FreeplayDJ(djOffset, djData);
			djTexts = dj.texts;
			if (!dj.loaded) dj = FlxDestroyUtil.destroy(dj);
		}
		if (djTexts == null) djTexts = ['BOYFRIEND', 'HOT BLOODED IN MORE WAYS THAN ONE', 'PROTECT YO NUTS'];

		backingCard = new BackingCard(this, djTexts, djOffset);
		add(backingCard);
		backingCard.applyExitMovers(exitMovers);

		if (dj != null)
		{
			add(dj);
			exitMovers.set([dj], {x: -Math.max(dj.width, 640) * 1.6, speed: 0.5});
		}

		backingImage = new FlxSprite(backingCard.pinkBack.width * 0.74, 0).loadGraphic(Paths.image(Std.string(style.bgAsset)));
		backingImage.antialiasing = Save.data.antialiasing;
		backingImage.shader = angleMaskShader;
		backingImage.visible = false;

		blackOverlay = new FlxSprite(FlxG.width).makeGraphic(Std.int(backingImage.width), Std.int(backingImage.height), FlxColor.BLACK);
		add(blackOverlay);
		backingImage.setGraphicSize(0, FlxG.height + 1);
		blackOverlay.setGraphicSize(0, FlxG.height + 1);
		backingImage.updateHitbox();
		blackOverlay.updateHitbox();
		blackOverlay.shader = angleMaskShader;
		exitMovers.set([blackOverlay, backingImage], {x: FlxG.width * 1.5, speed: 0.4, wait: 0});

		grpDifficulties = new FlxTypedSpriteGroup<DifficultySprite>(-300, 80);
		for (diff in allDifficulties)
		{
			var sprite:DifficultySprite = new DifficultySprite(diff);
			sprite.visible = sameDiff(diff, currentDifficulty);
			sprite.height *= 2.5;
			grpDifficulties.add(sprite);
		}
		add(grpDifficulties);
		exitMovers.set([grpDifficulties], {x: -300, speed: 0.25, wait: 0});

		difficultyDots = new FlxTypedGroup<DifficultyDot>();
		for (diff in allDifficulties) difficultyDots.add(new DifficultyDot(diff));
		add(difficultyDots);

		add(backingImage);

		grpCapsules = new FlxTypedGroup<SongMenuItem>();
		add(grpCapsules);

		albumRoll = new AlbumRoll();
		albumRoll.albumId = null;
		albumRoll.visible = false;
		albumRoll.applyExitMovers(exitMovers);
		add(albumRoll);

		overhang = new FlxSprite().makeGraphic(FlxG.width, 164, FlxColor.BLACK);
		overhang.y = -overhang.height;
		FlxTween.tween(overhang, {y: -100}, 0.3, {ease: FlxEase.quartOut});
		FlxTween.tween(blackOverlay, {x: backingImage.x}, 0.7, {ease: FlxEase.quintOut});

		topLeftText = new FlxText(8, 8, 0, Language.getPhrase('freeplay_title', 'FREEPLAY'), 48);
		topLeftText.font = Paths.font('vcr.ttf');
		topLeftText.visible = false;
		titleStroke = new StrokeShader(0xFFFFFFFF, 2, 2);
		topLeftText.shader = titleStroke;

		topLeftBg = new FlxSprite().makeGraphic(Math.round(topLeftText.width + 16), Math.round(topLeftText.height + 16), FlxColor.BLACK);
		topLeftBg.x = topLeftText.x - 8;
		topLeftBg.visible = false;

		ostName = new FlxText(8, 8, FlxG.width - 16, AlbumRoll.DEFAULT_OST_NAME, 48);
		ostName.font = Paths.font('vcr.ttf');
		ostName.alignment = RIGHT;
		ostName.visible = false;
		ostName.shader = new StrokeShader(0xFFFFFFFF, 2, 2);

		#if mobile
		var hint:String = Language.getPhrase('freeplay_hint_mobile', 'Drag to scroll • Tap a song twice to play • Swipe to change difficulty • Tap the DJ to change character');
		#else
		var hint:String = Language.getPhrase('freeplay_hint', '[TAB] Characters • [CTRL] Modifiers • [RESET] Reset • [F] Favorite • [Q/E] Sort');
		#end
		var hintX:Float = topLeftBg.x + topLeftBg.width + 24;
		hintText = new FlxText(hintX, 14, FlxG.width - hintX * 2, hint, 16);
		hintText.font = Paths.font('5by7.ttf');
		hintText.alignment = CENTER;
		hintText.color = 0xFF5F5F5F;
		hintText.y -= 100;
		FlxTween.tween(hintText, {y: hintText.y + 100}, 0.8, {ease: FlxEase.quartOut});

		exitMovers.set([overhang, topLeftText, topLeftBg, ostName, hintText], {y: -overhang.height, x: 0, speed: 0.2, wait: 0});

		highscoreSprite = new FlxSprite(FlxG.width - 420, 70);
		highscoreSprite.frames = Paths.getSparrowAtlas('freeplay/highscore');
		highscoreSprite.animation.addByPrefix('highscore', 'highscore small instance 1', 24, false);
		highscoreSprite.antialiasing = Save.data.antialiasing;
		highscoreSprite.visible = false;
		highscoreSprite.updateHitbox();
		add(highscoreSprite);
		new FlxTimer().start(FlxG.random.float(12, 50), function(timer:FlxTimer)
		{
			highscoreSprite.animation.play('highscore');
			timer.time = FlxG.random.float(20, 60);
		}, 0);

		scoreDisplay = new FreeplayScore(FlxG.width - 353, 60, 7, Std.string(style.numbersAsset));
		scoreDisplay.visible = false;
		add(scoreDisplay);

		clearBox = new FlxSprite(FlxG.width - 115, 65).loadGraphic(Paths.image('freeplay/clearBox'));
		clearBox.antialiasing = Save.data.antialiasing;
		clearBox.visible = false;
		add(clearBox);

		completionText = new CompletionText(FlxG.width - 95, 87);
		completionText.visible = false;
		add(completionText);

		letterSort = new LetterSort(songsOffset + 400, 75);
		letterSort.visible = false;
		letterSort.changeSelectionCallback = onLetterChanged;
		add(letterSort);
		exitMovers.set([letterSort], {y: -100, speed: 0.3});

		exitMovers.set([scoreDisplay, highscoreSprite, clearBox], {x: FlxG.width, speed: 0.3});
		exitMovers.set([completionText], {x: FlxG.width * 1.05, speed: 0.315});

		var selectorAsset:String = Std.string(style.selectorAsset);
		diffSelLeft = new DifficultySelector(djOffset + 20, grpDifficulties.y - 10, false, selectorAsset);
		diffSelRight = new DifficultySelector(djOffset + 325, grpDifficulties.y - 10, true, selectorAsset);
		diffSelLeft.visible = diffSelRight.visible = false;
		add(diffSelLeft);
		add(diffSelRight);

		add(overhang);
		add(topLeftBg);
		add(topLeftText);
		add(ostName);
		add(hintText);

		missingBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingBg.alpha = 0.6;
		missingBg.visible = false;
		add(missingBg);
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.visible = false;
		add(missingText);

		currentFilter = rememberedFilter;
		generateSongList(false);

		#if mobile
		createTouchButtons();
		#end

		if (dj != null) dj.onIntroDone.add(onDJIntroDone);
		else new FlxTimer().start(0.6, function(_) onDJIntroDone());

		super.create();
	}

	function loadSongs()
	{
		songs = [];
		allDifficulties = [];
		for (i in 0...LevelData.levelsList.length)
		{
			var name:String = LevelData.levelsList[i];
			if (levelIsLocked(name)) continue;
			var level:LevelData = LevelData.levelsLoaded.get(name);
			LevelData.setDirectoryFromLevel(level);
			for (entry in level.songs)
			{
				var data:FreeplaySongData = new FreeplaySongData(entry, level, i);
				data.setPlayer(currentCharacter);
				if (!data.available) continue;
				songs.push(data);
				for (diff in data.difficulties)
				{
					var exists:Bool = false;
					for (known in allDifficulties)
						if (sameDiff(known, diff)) exists = true;
					if (!exists) allDifficulties.push(diff);
				}
			}
		}
		LevelData.setDirectoryFromLevel();
		if (allDifficulties.length < 1) allDifficulties = Difficulty.defaultList.copy();

		currentDifficulty = null;
		var wanted:String = rememberedDifficulty != null ? rememberedDifficulty : Difficulty.getDefault();
		for (diff in allDifficulties)
			if (sameDiff(diff, wanted)) currentDifficulty = diff;
		if (currentDifficulty == null) currentDifficulty = allDifficulties[0];
	}

	function loadStyle()
	{
		style = {
			bgAsset: 'freeplay/freeplayBGweek1-bf',
			selectorAsset: 'freeplay/freeplaySelector/freeplaySelector',
			numbersAsset: 'digital_numbers',
			capsuleAsset: 'freeplay/freeplayCapsule/capsule/freeplayCapsule',
			capsuleTextColors: ['#00ccff', '#00ccff'],
			startDelay: 1.0
		};
		var raw:String = Paths.getTextFromFile('data/ui/freeplay/styles/${funkin.ui.charSelect.PlayerData.styleId(currentCharacter)}.json');
		if (raw == null) raw = Paths.getTextFromFile('data/ui/freeplay/styles/bf.json');
		if (raw == null) return;
		try
		{
			var parsed:Dynamic = Json.parse(raw);
			for (field in Reflect.fields(parsed))
				Reflect.setField(style, field, Reflect.field(parsed, field));
		}
		catch (e:Dynamic) {}
	}

	function levelIsLocked(name:String):Bool
	{
		var level:LevelData = LevelData.levelsLoaded.get(name);
		return (!level.startUnlocked && level.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(level.weekBefore) || !StoryMenuState.weekCompleted.get(level.weekBefore)));
	}

	static inline function sameDiff(a:String, b:String):Bool
		return a != null && b != null && Paths.formatToSongPath(a) == Paths.formatToSongPath(b);

	inline function get_currentCapsule():SongMenuItem
		return grpCapsules.members[curSelected];

	public function syncAngleMask()
		angleMaskShader.extraColor = backingImage.color;

	function onDJIntroDone()
	{
		if (uiState == Entering) uiState = Idle;

		albumRoll.playIntro();
		albumRoll.albumId = currentCapsule != null && currentCapsule.freeplayData != null ? currentCapsule.freeplayData.album : null;

		FlxTween.color(backingImage, 0.6, 0xFF000000, 0xFFFFFFFF, {
			ease: FlxEase.expoOut,
			onUpdate: function(_) syncAngleMask(),
			onComplete: function(_) blackOverlay.visible = false
		});

		FlxTween.cancelTweensOf(grpDifficulties);
		for (diff in grpDifficulties.members)
		{
			if (diff == null) continue;
			FlxTween.cancelTweensOf(diff);
			FlxTween.tween(diff, {x: djOffset + 90}, 0.6, {ease: FlxEase.quartOut});
			diff.y = 80;
			diff.visible = sameDiff(diff.difficultyId, currentDifficulty);
		}
		FlxTween.tween(grpDifficulties, {x: djOffset + 90}, 0.6, {ease: FlxEase.quartOut});

		diffSelLeft.visible = diffSelRight.visible = true;
		letterSort.visible = true;
		exitMovers.set([diffSelLeft, diffSelRight], {x: -diffSelLeft.width * 2, speed: 0.26});

		new FlxTimer().start(1 / 24, function(_)
		{
			highscoreSprite.visible = true;
			topLeftText.visible = topLeftBg.visible = true;
			ostName.visible = true;
			updateOSTName(true);
			scoreDisplay.visible = true;
			scoreDisplay.score = 0;
			clearBox.visible = true;
			completionText.visible = true;
			intendedCompletion = 0;
			new FlxTimer().start(1.5 / 24, function(_)
			{
				titleStroke.width = titleStroke.height = 0;
				changeSelection();
			});
		});

		backingImage.visible = true;
		backingCard.introDone();
		refreshDots(diffIndexOf(currentDifficulty), diffIndexOf(currentDifficulty));
		fadeDots(true);
	}

	function updateOSTName(force:Bool = false)
	{
		var name:String = albumRoll.getOSTName();
		if (!force && ostName.text == name) return;
		ostName.text = name;
		var stroke:StrokeShader = cast ostName.shader;
		stroke.width = stroke.height = 2;
		new FlxTimer().start(1.5 / 24, function(_) stroke.width = stroke.height = 0);
	}

	function onLetterChanged(filter:String)
	{
		var previous:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		if (currentCapsule != null) currentCapsule.selected = false;
		currentFilter = filter;
		rememberedFilter = filter;
		generateSongList(true);
		if (previous == null || !filteredSongs.contains(previous)) curSelected = filteredSongs.length > 0 ? 1 : 0;
		changeSelection();
	}

	function generateSongList(noJumpIn:Bool)
	{
		filteredSongs = [for (song in songs) if (song.matchesLetter(currentFilter) && song.hasDifficulty(currentDifficulty)) song];

		for (capsule in grpCapsules.members)
			if (capsule != null) capsule.destroy();
		grpCapsules.clear();

		var textColor:FlxColor = 0xFF00CCFF;
		var colors:Array<Dynamic> = style.capsuleTextColors;
		if (colors != null && colors.length > 0)
		{
			var parsed:Null<FlxColor> = FlxColor.fromString(Std.string(colors[0]));
			if (parsed != null) textColor = parsed;
		}

		var capsuleAsset:String = Std.string(style.capsuleAsset);
		rememberSelection();
		for (i in 0...filteredSongs.length + 1)
		{
			var data:FreeplaySongData = i == 0 ? null : filteredSongs[i - 1];
			var capsule:SongMenuItem = new SongMenuItem(FlxG.width, 0, capsuleAsset);
			capsule.cutoutOffset = songsOffset;
			capsule.applyStyle(textColor);
			capsule.curSelected = curSelected;
			capsule.initData(data, i, currentDifficulty);
			capsule.y = capsule.intendedY(i) + 10;
			capsule.targetPos.x = capsule.x;
			capsule.ID = i;
			if (i == 0) capsule.alpha = 0;
			else capsule.capsule.alpha = 0.5;
			capsule.newText.animation.curAnim.curFrame = 45 - ((i * 4) % 45);
			grpCapsules.add(capsule);
			if (noJumpIn)
			{
				capsule.targetPos.y = capsule.intendedY(i - curSelected);
				capsule.targetPos.x = capsule.intendedX(i - curSelected) + songsOffset;
				capsule.forcePosition();
				if (i == 0) capsule.alpha = 1;
			}
			else
			{
				capsule.initJumpIn(0, false);
				if (i == 0) FlxTween.tween(capsule, {alpha: 1}, 0.3, {startDelay: 0.2});
			}
		}

		if (noJumpIn) changeSelection();
	}

	function rememberSelection()
	{
		curSelected = 0;
		if (rememberedSong != null)
			for (i => song in filteredSongs)
				if ('${song.folder}:${song.songId}' == rememberedSong)
				{
					curSelected = i + 1;
					break;
				}
		curSelectedFloat = curSelected;
	}

	inline function diffIndexOf(diff:String):Int
	{
		var index:Int = -1;
		for (i => entry in allDifficulties)
			if (sameDiff(entry, diff)) index = i;
		return index;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		var count:Int = grpCapsules.length;
		if (count < 1) return;
		var previous:Int = curSelected;
		curSelected = FlxMath.wrap(curSelected + change, 0, count - 1);
		curSelectedFloat = curSelected;
		if (playSound && curSelected != previous) FunkinSound.playOnce('scrollMenu', 0.4);
		if (dj != null && change != 0) dj.onPlayerAction();

		var data:FreeplaySongData = currentCapsule.freeplayData;
		if (data != null) rememberedSong = '${data.folder}:${data.songId}';
		updateScoreTargets();

		for (i => capsule in grpCapsules.members)
		{
			capsule.forceHighlight = false;
			capsule.selected = i == curSelected;
			capsule.curSelected = curSelected;
			var position:Int = i - curSelected;
			var yOffset:Float = position < 0 ? 50 : (position > 4 ? -10 : 0);
			capsule.targetPos.y = capsule.intendedY(position) - yOffset;
			capsule.targetPos.x = capsule.intendedX(position) + songsOffset;
			if (i < curSelected) capsule.targetPos.y -= 100;
		}
		currentCapsule.refreshDisplay(currentDifficulty);

		if (uiState != Entering)
		{
			albumRoll.albumId = data != null ? data.album : null;
			if (data != null) albumRoll.setDifficultyStars(data.getRating(currentDifficulty));
			updateOSTName();
			refreshDots(diffIndexOf(currentDifficulty), -1);
			schedulePreview();
		}
	}

	function updateScoreTargets()
	{
		var data:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		intendedScore = data != null ? data.getScore(currentDifficulty) : 0;
		intendedCompletion = data != null ? Math.max(0, data.getAccuracy(currentDifficulty)) : 0;
		if (Math.isNaN(intendedCompletion)) intendedCompletion = 0;
	}

	function changeDiff(change:Int = 0)
	{
		if (change == 0 || allDifficulties.length < 2) return;

		var previousIndex:Int = diffIndexOf(currentDifficulty);
		for (diff in grpDifficulties.members)
		{
			if (diff == null || !sameDiff(diff.difficultyId, currentDifficulty)) continue;
			diff.visible = true;
			var newX:Float = (change > 0 ? -320 : 500) + djOffset;
			FlxTween.cancelTweensOf(diff);
			FlxTween.tween(diff, {x: newX}, 0.2, {
				ease: FlxEase.circInOut,
				onComplete: function(_)
				{
					diff.x = djOffset + 90;
					diff.visible = false;
				}
			});
		}

		FunkinSound.playOnce('scrollMenu', 0.4);
		(change > 0 ? diffSelRight : diffSelLeft).press();

		var index:Int = FlxMath.wrap(previousIndex + change, 0, allDifficulties.length - 1);
		currentDifficulty = allDifficulties[index];
		rememberedDifficulty = currentDifficulty;

		var previousSong:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		generateSongList(true);
		if (previousSong != null && !previousSong.hasDifficulty(currentDifficulty)) closestSongFor(previousSong);

		for (diff in grpDifficulties.members)
		{
			if (diff == null || !sameDiff(diff.difficultyId, currentDifficulty)) continue;
			FlxTween.cancelTweensOf(diff);
			diff.visible = true;
			diff.x = (change > 0 ? 500 : -320) + djOffset;
			FlxTween.tween(diff, {x: djOffset + 90}, 0.2, {ease: FlxEase.circInOut});
			diff.offset.y += 5;
			diff.alpha = 0.5;
			new FlxTimer().start(1 / 24, function(_)
			{
				diff.alpha = 1;
				diff.updateHitbox();
			});
		}

		refreshDots(index, previousIndex);
		if (currentCapsule != null) currentCapsule.refreshDisplay(currentDifficulty);
	}

	function closestSongFor(song:FreeplaySongData)
	{
		var index:Int = songs.indexOf(song);
		var best:Int = 0;
		var bestDistance:Int = 0x7FFFFFFF;
		for (i => entry in filteredSongs)
		{
			var distance:Int = Std.int(Math.abs(songs.indexOf(entry) - index));
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = i + 1;
			}
		}
		curSelected = filteredSongs.length > 0 ? best : 0;
		changeSelection();
	}

	function refreshDots(index:Int, prevIndex:Int)
	{
		var distance:Float = 30;
		var groupOffset:Float = 14.7;
		var count:Int = difficultyDots.length;
		var shown:Int = Std.int(Math.min(count, MAX_DOTS_PER_ROW));
		var baseX:Float = DOTS_POS[0] - groupOffset * (shown - 1);
		var data:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;

		for (i => dot in difficultyDots.members)
		{
			dot.x = djOffset + baseX + distance * (i % MAX_DOTS_PER_ROW) - (distance * 5) / 2;
			dot.y = DOTS_POS[1] + distance * Math.floor(i / MAX_DOTS_PER_ROW);
			var id:String = Paths.formatToSongPath(dot.difficultyId);
			var type:DotType = (id == 'erect' || id == 'nightmare') ? ERECT : NORMAL;
			if (data != null && !data.hasDifficulty(dot.difficultyId)) type = INACTIVE;
			dot.visible = count > 1;
			dot.updateState(type, i == index ? SELECTED : (i == prevIndex ? DESELECTING : DESELECTED));
		}
	}

	function fadeDots(fadeIn:Bool)
	{
		for (dot in difficultyDots.members)
			if (fadeIn) dot.fadeIn();
			else dot.fadeOut();
	}

	function schedulePreview()
	{
		clearPreviews();
		var token:Int = ++previewToken;
		previewTimers.push(new FlxTimer().start(FADE_IN_DELAY, function(_)
		{
			if (token == previewToken && uiState != Exiting) playPreview();
		}));
	}

	function clearPreviews()
	{
		for (timer in previewTimers)
			if (timer != null) timer.cancel();
		previewTimers = [];
	}

	function playPreview()
	{
		var volume:Float = 0.7 * (dj != null ? dj.getMusicPreviewMult() : 1);
		var data:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		if (data == null)
		{
			FunkinSound.playMusic('freeplayRandom/freeplayRandom', 0);
			if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(2, 0, volume);
			Conductor.bpm = 145;
			Conductor.bpmChangeMap = [];
			return;
		}

		var previous:String = Mods.currentModDirectory;
		Mods.currentModDirectory = data.folder;
		var source = data.previewFor(currentDifficulty);
		var inst:Sound = null;
		if (source.variation != null) inst = Paths.returnSound('${source.audio}/Inst-${source.variation}', 'songs', true, false);
		if (inst == null) inst = Paths.returnSound('${source.audio}/Inst', 'songs', true, false);
		Mods.currentModDirectory = previous;
		if (inst == null) return;

		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		FlxG.sound.playMusic(inst, 0);
		FlxG.sound.music.fadeIn(2, 0, volume);
		Conductor.bpm = data.bpmFor(currentDifficulty);
		Conductor.bpmChangeMap = [];
		curStep = curBeat = 0;
	}

	override public function beatHit()
	{
		super.beatHit();
		if (backingCard != null) backingCard.beatHit(curBeat);
	}

	override function update(elapsed:Float)
	{
		if (songs.length < 1 || grpCapsules == null)
		{
			super.update(elapsed);
			return;
		}

		if (FlxG.sound.music != null && FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;
		lerpScoreDisplays(elapsed);

		if (uiState == Idle && subState == null) handleInputs(elapsed);

		super.update(elapsed);
	}

	function lerpScoreDisplays(elapsed:Float)
	{
		lerpScore = MathUtil.smoothLerpPrecision(lerpScore, intendedScore, elapsed, 0.2);
		if (Math.abs(lerpScore - intendedScore) < 1 || Math.isNaN(lerpScore)) lerpScore = intendedScore;
		lerpCompletion = MathUtil.smoothLerpPrecision(lerpCompletion, intendedCompletion, elapsed, 0.5);
		if (Math.abs(lerpCompletion - intendedCompletion) < 0.01 || Math.isNaN(lerpCompletion)) lerpCompletion = intendedCompletion;

		scoreDisplay.score = Std.int(lerpScore);
		completionText.value = Std.int(FlxMath.bound(Math.floor(lerpCompletion * 100), 0, 100));
	}

	function handleInputs(elapsed:Float)
	{
		#if mobile
		if (handleTouch()) return;
		#end

		var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
		var count:Int = grpCapsules.length;

		if (count > 1)
		{
			if (FlxG.keys.justPressed.HOME)
			{
				curSelected = 0;
				changeSelection();
			}
			else if (FlxG.keys.justPressed.END)
			{
				curSelected = count - 1;
				changeSelection();
			}

			if (controls.UI_UP_P)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}
			if (controls.UI_DOWN || controls.UI_UP)
			{
				var lastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var newHold:Int = Math.floor((holdTime - 0.5) * 10);
				if (holdTime > 0.5 && newHold - lastHold > 0)
					changeSelection((newHold - lastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
			}
			if (FlxG.mouse.wheel != 0) changeSelection(-shiftMult * FlxG.mouse.wheel);
		}

		if (controls.UI_LEFT_P) changeDiff(-1);
		else if (controls.UI_RIGHT_P) changeDiff(1);

		if (FlxG.keys.justPressed.Q) letterSort.changeSelection(-1);
		else if (FlxG.keys.justPressed.E) letterSort.changeSelection(1);

		if (FlxG.keys.justPressed.F) toggleFavorite();
		if (FlxG.keys.justPressed.TAB)
		{
			openCharSelect();
			return;
		}

		if (controls.BACK) goBack();
		else if (FlxG.keys.justPressed.CONTROL) openChangers();
		else if (controls.RESET) openReset();
		else if (controls.ACCEPT) acceptSelection();
	}

	function openCharSelect()
	{
		if (funkin.ui.charSelect.PlayerData.list().length < 2) return;
		uiState = Exiting;
		clearPreviews();
		previewToken++;
		FunkinSound.playOnce('confirmMenu');
		if (FlxG.sound.music != null) FlxG.sound.music.fadeOut(0.5, 0);
		FlxG.camera.fade(FlxColor.BLACK, 0.5, false, function()
		{
			startingSong = true;
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new funkin.ui.charSelect.CharSelectState(currentCharacter));
		});
	}

	function toggleFavorite()
	{
		var data:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		if (data == null) return;
		var fav:Bool = data.toggleFavorite();
		currentCapsule.setFavorite(fav);
		FunkinSound.playOnce(fav ? 'fav' : 'unfav');
		if (dj != null) dj.onPlayerAction();
		if (!fav && currentFilter == 'fav')
		{
			generateSongList(true);
			curSelected = Std.int(Math.min(curSelected, grpCapsules.length - 1));
			changeSelection();
		}
	}

	function openChangers()
	{
		persistentUpdate = false;
		openSubState(new GameplayChangersSubstate());
	}

	function openReset()
	{
		var data:FreeplaySongData = currentCapsule != null ? currentCapsule.freeplayData : null;
		if (data == null) return;
		persistentUpdate = false;
		var chart:FreeplaySongData.FreeplayChart = data.chartFor(currentDifficulty);
		if (chart == null) return;
		Mods.currentModDirectory = data.folder;
		Difficulty.copyFrom(chart.list);
		openSubState(new ResetScoreSubState(chart.song, chart.index, data.icon));
		FunkinSound.playOnce('scrollMenu');
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		super.closeSubState();
		if (grpCapsules != null && currentCapsule != null)
		{
			updateScoreTargets();
			currentCapsule.refreshDisplay(currentDifficulty);
		}
	}

	function acceptSelection()
	{
		if (grpCapsules.length < 1) return;
		if (curSelected == 0)
		{
			if (filteredSongs.length < 1)
			{
				FunkinSound.playOnce('cancelMenu');
				return;
			}
			curSelected = FlxG.random.int(1, filteredSongs.length);
			changeSelection(0, false);
		}
		confirmSong(currentCapsule);
	}

	function confirmSong(capsule:SongMenuItem)
	{
		var data:FreeplaySongData = capsule.freeplayData;
		if (data == null) return;

		uiState = Exiting;
		clearPreviews();
		previewToken++;
		FunkinSound.playOnce('confirmMenu');
		if (dj != null) dj.onConfirm();
		capsule.forcePosition();
		capsule.confirm();
		backingCard.confirm();
		fadeDots(false);

		#if mobile
		changersButton.visible = resetButton.visible = false;
		#end

		var delay:Float = style.startDelay != null ? Std.parseFloat(Std.string(style.startDelay)) : 1.0;
		if (Math.isNaN(delay)) delay = 1.0;
		new FlxTimer().start(delay, function(_) startSong(data));
	}

	function startSong(data:FreeplaySongData)
	{
		Mods.currentModDirectory = data.folder;
		PlayState.storyWeek = data.levelIndex;
		var chart:FreeplaySongData.FreeplayChart = data.chartFor(currentDifficulty);
		var chartSong:String = chart != null ? chart.song : data.songId;
		Difficulty.copyFrom(chart != null ? chart.list : data.difficulties);
		var index:Int = chart != null ? chart.index : 0;

		try
		{
			Song.loadFromJson(Highscore.formatSong(chartSong, index), chartSong);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = index;
		}
		catch (e:haxe.Exception)
		{
			var error:String = e.message;
			if (error.contains('There is no TEXT asset with an ID of')) error = 'Missing file: ' + error.substring(error.indexOf(data.songId), error.length - 1);
			else error += '\n\n' + e.stack;
			missingText.text = 'ERROR WHILE LOADING CHART:\n$error';
			missingText.screenCenter(Y);
			missingText.visible = missingBg.visible = true;
			FunkinSound.playOnce('cancelMenu');
			new FlxTimer().start(2.5, function(_) MusicBeatState.resetState());
			return;
		}

		startingSong = true;
		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory) Paths.freeGraphicsFromMemory();
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		#end
		destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}

	function goBack()
	{
		if (uiState == Exiting) return;
		uiState = Exiting;
		clearPreviews();
		previewToken++;
		FlxTween.globalManager.clear();
		FlxTimer.globalManager.clear();
		if (dj != null) dj.onIntroDone.removeAll();
		FunkinSound.playOnce('cancelMenu');

		backingCard.disappear();
		fadeDots(false);

		var longest:Float = 0;
		for (sprites => data in exitMovers)
		{
			for (sprite in sprites)
			{
				if (sprite == null) continue;
				var speed:Float = data.speed != null ? data.speed : 0.2;
				var wait:Float = data.wait != null ? data.wait : 0;
				FlxTween.tween(sprite, {x: data.x != null ? data.x : sprite.x, y: data.y != null ? data.y : sprite.y}, speed, {ease: FlxEase.expoIn});
				longest = Math.max(longest, speed + wait);
			}
		}

		for (capsule in grpCapsules.members)
		{
			capsule.doJumpIn = false;
			capsule.doLerp = false;
			capsule.doJumpOut = true;
		}

		#if mobile
		for (button in [changersButton, resetButton]) FlxTween.tween(button, {alpha: 0}, 0.2);
		#end

		new FlxTimer().start(longest, function(_)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FunkinSound.playMusic('freakyMenu', 0);
			if (FlxG.sound.music != null) FlxG.sound.music.fadeIn(2, 0, 1);
			MusicBeatState.switchState(new MainMenuState());
		});
	}

	#if mobile
	function createTouchButtons()
	{
		backButton = funkin.mobile.controls.MobileButton.back();
		backButton.alpha = 0.3;
		add(backButton);

		var buttonY:Float = backButton.y - 56;
		resetButton = makeTouchButton(Language.getPhrase('freeplay_touch_reset', 'RESET'), 'reset', FlxG.width - 176, buttonY);
		changersButton = makeTouchButton(Language.getPhrase('freeplay_touch_changers', 'MODIFIERS'), 'modifiers', resetButton.x - 170, buttonY);
	}

	function makeTouchButton(label:String, image:String, x:Float, y:Float):funkin.mobile.controls.TouchButton
	{
		var button:funkin.mobile.controls.TouchButton = new funkin.mobile.controls.TouchButton(x, y, label);
		button.useImage(Paths.image('mobile/freeplay/$image'));
		add(button);
		return button;
	}

	function handleTouch():Bool
	{
		TouchInput.blockGestures = true;

		if (changersButton.justTapped)
		{
			openChangers();
			return true;
		}
		if (resetButton.justTapped)
		{
			openReset();
			return true;
		}

		if (TouchInput.justSwiped('ui_left') || TouchInput.justSwiped('ui_right'))
		{
			changeDiff(TouchInput.justSwiped('ui_left') ? -1 : 1);
			return true;
		}

		if (grpCapsules.length > 1 && TouchInput.isDragging())
		{
			var step:Float = 100;
			dragAccum += TouchInput.dragDeltaY();
			while (dragAccum >= step)
			{
				dragAccum -= step;
				changeSelection(-1);
			}
			while (dragAccum <= -step)
			{
				dragAccum += step;
				changeSelection(1);
			}
			return true;
		}
		dragAccum = 0;

		if (!TouchInput.justTapped()) return false;
		var tapX:Float = TouchInput.tapX;
		var tapY:Float = TouchInput.tapY;

		if (TouchInput.overlapsScreen(diffSelLeft, tapX, tapY, null, 20))
		{
			changeDiff(-1);
			return true;
		}
		if (TouchInput.overlapsScreen(diffSelRight, tapX, tapY, null, 20))
		{
			changeDiff(1);
			return true;
		}

		for (i => hitbox in letterSort.hitboxes)
		{
			if (i == 2 || !TouchInput.overlapsScreen(hitbox, tapX, tapY, null, 10)) continue;
			var change:Int = i < 2 ? -1 : 1;
			letterSort.changeSelection(change);
			if (i == 0 || i == 4) letterSort.changeSelection(change, false);
			return true;
		}

		if (tapX < djOffset + 250 && tapY > 220 && dj != null)
		{
			openCharSelect();
			return true;
		}

		for (i => capsule in grpCapsules.members)
		{
			if (!capsule.visible || !TouchInput.overlapsScreen(capsule.hitbox, tapX, tapY, null, 0)) continue;
			if (i == curSelected) acceptSelection();
			else changeSelection(i - curSelected);
			return true;
		}
		return false;
	}

	override function openSubState(subState:flixel.FlxSubState)
	{
		funkin.mobile.input.TouchInput.blockGestures = false;
		super.openSubState(subState);
	}
	#end

	override function destroy():Void
	{
		#if mobile
		funkin.mobile.input.TouchInput.blockGestures = false;
		#end
		clearPreviews();
		super.destroy();
		FlxG.autoPause = Save.data.autoPause;
		if ((FlxG.sound.music == null || !FlxG.sound.music.playing) && !startingSong) FunkinSound.playMusic('freakyMenu');
	}
}

class CompletionText extends FlxSpriteGroup
{
	public var value(default, set):Int = -1;

	var digits:Array<FlxSprite> = [];

	public function new(x:Float, y:Float)
	{
		super(x, y);
		for (i in 0...3)
		{
			var digit:FlxSprite = new FlxSprite(i * 24, 0);
			digit.frames = Paths.getSparrowAtlas('fonts/freeplay-clear');
			for (n in 0...10) digit.animation.addByPrefix('$n', '$n', 24, false);
			digit.antialiasing = Save.data.antialiasing;
			add(digit);
			digits.push(digit);
		}
		value = 0;
	}

	function set_value(newValue:Int):Int
	{
		if (value == newValue) return newValue;
		value = newValue;
		var text:String = Std.string(newValue);
		for (i => digit in digits)
		{
			digit.visible = i < text.length;
			if (digit.visible) digit.animation.play(text.charAt(i), true);
		}
		var shift:Float = switch (text.length)
		{
			case 3: 10;
			case 1: -24;
			default: 0;
		}
		for (i => digit in digits) digit.offset.x = shift;
		return newValue;
	}
}
