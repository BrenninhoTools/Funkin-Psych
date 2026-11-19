package funkin.ui.mainmenu;

import funkin.play.PlayState;
import funkin.ui.achievements.AchievementsMenuState;
import funkin.ui.credits.CreditsState;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.mods.ModsMenuState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.title.TitleState;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import funkin.ui.debug.MasterEditorMenu;
import funkin.ui.options.OptionsState;
import funkin.data.DataUtil;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = #if mobile false #else true #end;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var optionShit:Array<String> = [];
	var optionData:Map<String, Dynamic> = [];
	var leftOption:String = null;
	var rightOption:String = null;

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var menu:funkin.data.menu.MenuData;

	public static function defaultData():Dynamic
	{
		return {
			version: funkin.data.menu.MenuData.VERSION,
			music: {maxVolume: 0.8, fadeSpeed: 0.5},
			sounds: {scroll: 'scrollMenu', confirm: 'confirmMenu', cancel: 'cancelMenu'},
			camera: {followLerp: 0.15},
			background: {image: 'menuBG', position: [-80, 0], scale: 1.175, scroll: [0, 0.25], center: true},
			flash: {image: 'menuDesat', position: [-80, 0], scale: 1.175, scroll: [0, 0.25], center: true, color: '#FD719B', duration: 1.1, interval: 0.15},
			layout: {startY: 90, spacing: 140, centerX: true, balance: 4},
			items: [
				{id: 'story_mode', target: 'story'},
				{id: 'freeplay', target: 'freeplay'},
				{id: 'mods', target: 'mods', requires: 'mods'},
				{id: 'credits', target: 'credits'}
			],
			left: {id: 'achievements', target: 'achievements', position: [60, 490], requires: 'achievements'},
			right: {id: 'options', target: 'options', position: [-60, 490], alignRight: true},
			texts: [
				{text: 'Psych Engine v{psychVersion}', position: [12, 676], size: 16, alignment: 'left', width: -1},
				{text: "Friday Night Funkin' v{fnfVersion}", position: [12, 696], size: 16, alignment: 'left', width: -1}
			],
			sprites: []
		};
	}

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;
		menu = funkin.data.menu.MenuData.load('mainmenu', defaultData());

		var bg:FlxSprite = createBackground('background');
		add(bg);

		var back:FlxSpriteGroup = new FlxSpriteGroup();
		menu.createSprites(back, null, false, variables);
		add(back);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = createBackground('flash');
		magenta.visible = false;
		magenta.color = menu.colorOf('flash', 'color', 0xFFfd719b);
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (info in menu.list('items'))
		{
			if (!funkin.data.menu.MenuData.requirementMet(info)) continue;
			var id:String = Std.string(info.id);
			optionShit.push(id);
			optionData.set(id, info);
		}

		var startY:Float = menu.float('layout', 'startY', 90);
		var spacing:Float = menu.float('layout', 'spacing', 140);
		var balance:Int = menu.int('layout', 'balance', 4);
		for (num => option in optionShit)
		{
			var info:Dynamic = optionData.get(option);
			var item:FlxSprite = createMenuItem(info, 0, (num * spacing) + startY);
			if (balance > 0) item.y += (balance - optionShit.length) * (spacing / 2);
			if (info.position != null)
			{
				var pos:Array<Float> = DataUtil.vector(info.position);
				item.setPosition(pos[0], pos[1]);
			}
			else if (menu.bool('layout', 'centerX', true)) item.screenCenter(X);
			else item.x = menu.float('layout', 'x', 0);
		}

		var leftInfo:Dynamic = Reflect.field(menu.data, 'left');
		if (leftInfo != null && leftInfo.id != null && funkin.data.menu.MenuData.requirementMet(leftInfo))
		{
			leftOption = Std.string(leftInfo.id);
			optionData.set(leftOption, leftInfo);
			var pos:Array<Float> = DataUtil.vector(leftInfo.position, 60, 490);
			leftItem = createMenuItem(leftInfo, pos[0] < 0 ? FlxG.width + pos[0] : pos[0], pos[1]);
			if (DataUtil.toBool(leftInfo.alignRight)) leftItem.x -= leftItem.width;
		}

		var rightInfo:Dynamic = Reflect.field(menu.data, 'right');
		if (rightInfo != null && rightInfo.id != null && funkin.data.menu.MenuData.requirementMet(rightInfo))
		{
			rightOption = Std.string(rightInfo.id);
			optionData.set(rightOption, rightInfo);
			var pos:Array<Float> = DataUtil.vector(rightInfo.position, -60, 490);
			rightItem = createMenuItem(rightInfo, pos[0] < 0 ? FlxG.width + pos[0] : pos[0], pos[1]);
			if (rightInfo.alignRight != false) rightItem.x -= rightItem.width;
		}

		var values:Map<String, Dynamic> = [
			'psychVersion' => psychEngineVersion,
			'fnfVersion' => Application.current.meta.get('version'),
			'title' => Application.current.meta.get('title')
		];
		for (num => info in menu.list('texts'))
		{
			if (info == null || !funkin.data.menu.MenuData.requirementMet(info)) continue;
			var key:String = '_text$num';
			Reflect.setField(menu.data, key, info);
			var text:FlxText = menu.createText(key, funkin.data.ui.UIData.format(Std.string(info.text), values), -1, 16);
			if (DataUtil.toFloat(info.width, -1) == -1) text.fieldWidth = 0;
			add(text);
		}

		var front:FlxSpriteGroup = new FlxSpriteGroup();
		menu.createSprites(front, null, true, variables);
		add(front);

		if (optionShit.length < 1 && leftOption == null && rightOption == null)
		{
			optionShit.push('story_mode');
			optionData.set('story_mode', {id: 'story_mode', target: 'story'});
			createMenuItem(optionData.get('story_mode'), 0, startY).screenCenter(X);
		}
		if (curSelected >= optionShit.length) curSelected = 0;
		if ((curColumn == LEFT && leftItem == null) || (curColumn == RIGHT && rightItem == null)) curColumn = CENTER;
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && Save.data.checkForUpdates && funkin.ui.title.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new funkin.ui.title.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, menu.float('camera', 'followLerp', 0.15));

		#if mobile
		var backButton:funkin.mobile.controls.MobileButton = funkin.mobile.controls.MobileButton.back(null, true);
		add(backButton);
		editorsButton = new funkin.mobile.controls.ImageButton(16, 50, 'editorButton', 0.6);
		add(editorsButton);
		#end
	}

	static var showOutdatedWarning:Bool = true;

	function createBackground(name:String):FlxSprite
	{
		var pos:Array<Float> = menu.vector(name, 'position', -80, 0);
		var sprite:FlxSprite = new FlxSprite(pos[0], pos[1]).loadGraphic(Paths.image(menu.image(name, name == 'flash' ? 'menuDesat' : 'menuBG')));
		sprite.antialiasing = Save.data.antialiasing;
		var scroll:Array<Float> = menu.vector(name, 'scroll', 0, 0.25);
		sprite.scrollFactor.set(scroll[0], scroll[1]);
		sprite.setGraphicSize(Std.int(sprite.width * menu.float(name, 'scale', 1.175)));
		sprite.updateHitbox();
		if (menu.bool(name, 'center', true)) sprite.screenCenter();
		funkin.mobile.screen.WideScreen.fit(sprite);
		return sprite;
	}

	function createMenuItem(info:Dynamic, x:Float, y:Float):FlxSprite
	{
		var name:String = Std.string(info.id);
		var menuItem:FlxSprite = new FlxSprite(x, y);
		var render:Dynamic = info.render != null ? info.render : {};
		var image:String = render.image != null ? funkin.graphics.FrameLoader.joinImages(render.image) : (info.image != null ? Std.string(info.image) : 'mainmenu/menu_$name');
		var type:String = funkin.graphics.FrameLoader.resolveType(image, render.type);
		if (!funkin.graphics.FrameLoader.apply(menuItem, image, type, DataUtil.intVector(render.frameSize)))
			menuItem.frames = Paths.getSparrowAtlas(image);
		var idle:Dynamic = info.idle != null ? info.idle : '$name idle';
		var selected:Dynamic = info.selected != null ? info.selected : '$name selected';
		funkin.graphics.FrameLoader.addAnimation(menuItem, 'idle', Std.string(idle), null, DataUtil.toFloat(info.fps, 24), true, type);
		funkin.graphics.FrameLoader.addAnimation(menuItem, 'selected', Std.string(selected), null, DataUtil.toFloat(info.fps, 24), true, type);
		menuItem.animation.play('idle');
		var scale:Array<Float> = DataUtil.vector(info.scale, 1, 1);
		menuItem.scale.set(scale[0], scale[1]);
		menuItem.updateHitbox();

		menuItem.antialiasing = info.antialiasing != false && Save.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	function selectOption(option:String, item:FlxSprite)
	{
		var info:Dynamic = optionData.get(option);
		var target:String = info != null && info.target != null ? Std.string(info.target) : option;
		if (target.startsWith('url:'))
		{
			CoolUtil.browserLoad(target.substr(4));
			selectedSomethin = false;
			item.visible = true;
			return;
		}
		if (target.startsWith('state:'))
		{
			var cls:Class<Dynamic> = funkin.modding.LegacyClasses.resolveClass(target.substr(6));
			if (cls != null)
			{
				MusicBeatState.switchState(Type.createInstance(cls, []));
				return;
			}
		}
		switch (target)
		{
			case 'story', 'story_mode':
				MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());
			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(new ModsMenuState());
			#end
			#if ACHIEVEMENTS_ALLOWED
			case 'achievements', 'awards':
				MusicBeatState.switchState(new AchievementsMenuState());
			#end
			case 'credits':
				MusicBeatState.switchState(new CreditsState());
			case 'options':
				MusicBeatState.switchState(new OptionsState());
				OptionsState.onPlayState = false;
				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}
			case 'donate':
				CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				selectedSomethin = false;
				item.visible = true;
			case 'title':
				MusicBeatState.switchState(new TitleState());
			case 'editors':
				MusicBeatState.switchState(new MasterEditorMenu());
			default:
				selectedSomethin = false;
				item.visible = true;
		}
	}

	var selectedSomethin:Bool = false;
	#if mobile
	var editorsButton:funkin.mobile.controls.ImageButton;
	#end

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		var maxVolume:Float = menu.float('music', 'maxVolume', 0.8);
		if (FlxG.sound.music != null && FlxG.sound.music.volume < maxVolume)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + menu.float('music', 'fadeSpeed', 0.5) * elapsed, maxVolume);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			var touchAccept:Bool = false;
			#if mobile
			if (funkin.mobile.input.TouchInput.justTapped())
			{
				funkin.mobile.input.TouchInput.consumeTap();
				var selectedItem:FlxSprite = switch(curColumn)
				{
					case CENTER: menuItems.members[curSelected];
					case LEFT: leftItem;
					case RIGHT: rightItem;
				}

				var tappedItem:FlxSprite = null;
				if (leftItem != null && funkin.mobile.input.TouchInput.tappedOn(leftItem))
				{
					tappedItem = leftItem;
					if (tappedItem != selectedItem) curColumn = LEFT;
				}
				else if (rightItem != null && funkin.mobile.input.TouchInput.tappedOn(rightItem))
				{
					tappedItem = rightItem;
					if (tappedItem != selectedItem) curColumn = RIGHT;
				}
				else
				{
					for (i in 0...optionShit.length)
					{
						if (funkin.mobile.input.TouchInput.tappedOn(menuItems.members[i]))
						{
							tappedItem = menuItems.members[i];
							if (tappedItem != selectedItem)
							{
								curColumn = CENTER;
								curSelected = i;
							}
							break;
						}
					}
				}

				if (tappedItem != null)
				{
					if (tappedItem == selectedItem) touchAccept = true;
					else changeItem();
				}
			}

			if (editorsButton.justTapped)
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FunkinSound.playOnce(menu.sound('cancel', 'cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || touchAccept || (FlxG.mouse.justPressed && allowMouse))
			{
				FunkinSound.playOnce(menu.sound('confirm', 'confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (Save.data.flashing)
					FlxFlicker.flicker(magenta, menu.float('flash', 'duration', 1.1), menu.float('flash', 'interval', 0.15), false);

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker) selectOption(option, item));

				for (memb in menuItems)
				{
					if(memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FunkinSound.playOnce(menu.sound('scroll', 'scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
