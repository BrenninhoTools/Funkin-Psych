package funkin.ui.options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;

import funkin.ui.options.Option;
import funkin.input.InputFormatter;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxes:Map<Int, PreferenceCheckbox> = [];
	private var valueTexts:Map<Int, Alphabet> = [];

	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;

	var menuCamera:FlxCamera;
	var camFollow:flixel.FlxObject;

	public function new()
	{
		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		bg = OptionsState.createBackground();
		add(bg);

		menuCamera = new FlxCamera();
		menuCamera.bgColor = 0x0;
		FlxG.cameras.add(menuCamera, false);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...optionsArray.length)
		{
			var option:Option = optionsArray[i];
			var optionText:Alphabet = new Alphabet(120, 120 * i + 30, option.name.toUpperCase(), true);
			optionText.cameras = [menuCamera];
			grpOptions.add(optionText);

			if (option.type == BOOL)
			{
				var checkbox:PreferenceCheckbox = new PreferenceCheckbox(0, 120 * i, Std.string(option.getValue()) == 'true');
				checkbox.cameras = [menuCamera];
				checkboxes.set(i, checkbox);
				add(checkbox);
			}
			else if (option.type != BUTTON)
			{
				var valueText:Alphabet = new Alphabet(15, 120 * i + 30, '', false);
				valueText.cameras = [menuCamera];
				valueTexts.set(i, valueText);
				add(valueText);
				option.child = valueText;
			}
			updateTextFrom(option);
		}

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		descBox.scrollFactor.set();
		add(descBox);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 3;
		add(descText);

		camFollow = new flixel.FlxObject(FlxG.width / 2, 0, 140, 70);
		menuCamera.follow(camFollow, null, 0.085);
		var margin:Float = 160;
		menuCamera.deadzone.set(0, margin, menuCamera.width, menuCamera.height - margin * 2);
		menuCamera.minScrollY = 0;

		silentSelection = true;
		changeSelection();
		silentSelection = false;
		layoutItems();
		menuCamera.snapToTarget();

		#if mobile
		add(funkin.mobile.controls.MobileButton.back());
		#end
	}

	function layoutItems()
	{
		for (i => item in grpOptions.members)
		{
			var offsetX:Float = 0;
			var valueText:Alphabet = valueTexts.get(i);
			if (valueText != null) offsetX = valueText.width - 75;
			offsetX += i == curSelected ? 150 : 120;
			item.x = offsetX;
		}
	}

	override function close()
	{
		if (menuCamera != null)
		{
			FlxG.cameras.remove(menuCamera);
			menuCamera = null;
		}
		super.close();
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bindingKey:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:Alphabet;
	var bindingText2:Alphabet;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (menuCamera == null) return;
		layoutItems();
		if (grpOptions.members[curSelected] != null) camFollow.y = grpOptions.members[curSelected].y;

		if(bindingKey)
		{
			bindingKeyUpdate(elapsed);
			return;
		}

		var touchAccept:Bool = false;
		#if mobile
		if (funkin.mobile.input.TouchInput.justTapped())
		{
			for (i => item in grpOptions.members)
			{
				var row:Bool = funkin.mobile.input.TouchInput.overlapsScreen(item, funkin.mobile.input.TouchInput.tapX, funkin.mobile.input.TouchInput.tapY, menuCamera, 10);
				var box:PreferenceCheckbox = checkboxes.get(i);
				if (!row && box != null) row = funkin.mobile.input.TouchInput.overlapsScreen(box, funkin.mobile.input.TouchInput.tapX, funkin.mobile.input.TouchInput.tapY, menuCamera, 10);
				if (!row) continue;
				funkin.mobile.input.TouchInput.consumeTap();
				if (i == curSelected) touchAccept = true;
				else changeSelection(i - curSelected);
				break;
			}
		}
		#end

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			FunkinSound.playOnce('cancelMenu');
			close();
			return;
		}

		if(nextAccept <= 0)
		{
			switch(curOption.type)
			{
				case BOOL:
					if(controls.ACCEPT || touchAccept)
					{
						FunkinSound.playOnce('scrollMenu');
						curOption.setValue((curOption.getValue() == true) ? false : true);
						curOption.change();
						reloadCheckboxes();
					}

				case BUTTON:
					if(controls.ACCEPT || touchAccept)
					{
						FunkinSound.playOnce('scrollMenu');
						curOption.change();
					}

				case KEYBIND:
					if(controls.ACCEPT || touchAccept)
					{
						bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
						bindingBlack.scale.set(FlxG.width, FlxG.height);
						bindingBlack.updateHitbox();
						bindingBlack.alpha = 0;
						FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
						add(bindingBlack);
	
						bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), false);
						bindingText.alignment = CENTERED;
						add(bindingText);
						
						bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold ESC to Cancel\nHold Backspace to Delete'), true);
						bindingText2.alignment = CENTERED;
						add(bindingText2);
	
						bindingKey = true;
						holdingEsc = 0;
						Save.toggleVolumeKeys(false);
						FunkinSound.playOnce('scrollMenu');
					}

				default:
					if(controls.UI_LEFT || controls.UI_RIGHT)
					{
						var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
						if(holdTime > 0.5 || pressed)
						{
							if(pressed)
							{
								var add:Dynamic = null;
								if(curOption.type != STRING)
									add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
		
								switch(curOption.type)
								{
									case INT, FLOAT, PERCENT:
										holdValue = curOption.getValue() + add;
										if(holdValue < curOption.minValue) holdValue = curOption.minValue;
										else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
		
										if(curOption.type == INT)
										{
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);
										}
										else
										{
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
										}
		
									case STRING:
										var num:Int = curOption.curOption; //lol
										if(controls.UI_LEFT_P) --num;
										else num++;
		
										if(num < 0)
											num = curOption.options.length - 1;
										else if(num >= curOption.options.length)
											num = 0;
		
										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);
										//trace(curOption.options[num]);

									default:
								}
								updateTextFrom(curOption);
								curOption.change();
								FunkinSound.playOnce('scrollMenu');
							}
							else if(curOption.type != STRING)
							{
								holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
								if(holdValue < curOption.minValue) holdValue = curOption.minValue;
								else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
		
								switch(curOption.type)
								{
									case INT:
										curOption.setValue(Math.round(holdValue));
									
									case PERCENT:
										curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));

									default:
								}
								updateTextFrom(curOption);
								curOption.change();
							}
						}
		
						if(curOption.type != STRING)
							holdTime += elapsed;
					}
					else if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
					{
						if(holdTime > 0.5) FunkinSound.playOnce('scrollMenu');
						holdTime = 0;
					}
			}

			if(controls.RESET && optionsArray[curSelected].type != BUTTON)
			{
				var leOption:Option = optionsArray[curSelected];
				if(leOption.type != KEYBIND)
				{
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != BOOL)
					{
						if(leOption.type == STRING) leOption.curOption = leOption.options.indexOf(leOption.getValue());
						updateTextFrom(leOption);
					}
				}
				else
				{
					leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
					updateBind(leOption);
				}
				leOption.change();
				FunkinSound.playOnce('cancelMenu');
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
	}

	function bindingKeyUpdate(elapsed:Float)
	{
		if(FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				FunkinSound.playOnce('cancelMenu');
				closeBinding();
			}
		}
		else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				if (!controls.controllerMode) curOption.keys.keyboard = NONE;
				else curOption.keys.gamepad = NONE;
				updateBind(!controls.controllerMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
				FunkinSound.playOnce('cancelMenu');
				closeBinding();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed:Bool = false;
			if(!controls.controllerMode)
			{
				if(FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
					var keyReleased:FlxKey = cast (FlxG.keys.firstJustReleased(), FlxKey);

					if(keyPressed != NONE && keyPressed != ESCAPE && keyPressed != BACKSPACE)
					{
						changed = true;
						curOption.keys.keyboard = keyPressed;
					}
					else if(keyReleased != NONE && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
					{
						changed = true;
						curOption.keys.keyboard = keyReleased;
					}
				}
			}
			else if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:FlxGamepadInputID = NONE;
				var keyReleased:FlxGamepadInputID = NONE;
				if(FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
					keyPressed = LEFT_TRIGGER; //it wasnt working for some reason
				else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER; //it wasnt working for some reason
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
						if(gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();
							if(keyPressed != NONE || keyReleased != NONE) break;
						}
					}
				}

				if(keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					changed = true;
					curOption.keys.gamepad = keyPressed;
				}
				else if(keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					changed = true;
					curOption.keys.gamepad = keyReleased;
				}
			}

			if(changed)
			{
				var key:String = null;
				if(!controls.controllerMode)
				{
					if(curOption.keys.keyboard == null) curOption.keys.keyboard = 'NONE';
					curOption.setValue(curOption.keys.keyboard);
					key = InputFormatter.getKeyName(FlxKey.fromString(curOption.keys.keyboard));
				}
				else
				{
					if(curOption.keys.gamepad == null) curOption.keys.gamepad = 'NONE';
					curOption.setValue(curOption.keys.gamepad);
					key = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(curOption.keys.gamepad));
				}
				updateBind(key);
				FunkinSound.playOnce('confirmMenu');
				closeBinding();
			}
		}
	}

	final MAX_KEYBIND_WIDTH = 320;
	function updateBind(?text:String = null, ?option:Option = null)
	{
		if(option == null) option = curOption;
		if(text == null)
		{
			text = option.getValue();
			if(text == null) text = 'NONE';

			if(!controls.controllerMode)
				text = InputFormatter.getKeyName(FlxKey.fromString(text));
			else
				text = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(text));
		}

		var bind:Alphabet = option.child;
		if (bind == null) return;
		bind.scaleX = 1;
		bind.text = text;
		playstationCheck(bind);
		bind.scaleX = Math.min(1, MAX_KEYBIND_WIDTH / Math.max(1, bind.width));
	}

	function playstationCheck(alpha:Alphabet)
	{
		if(!controls.controllerMode) return;

		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
		var letter = alpha.letters[0];
		if(model == PS4)
		{
			switch(alpha.text)
			{
				case '[', ']': //Square and Triangle respectively
					letter.image = 'alphabet_playstation';
					letter.updateHitbox();
					
					letter.offset.x += 4;
					letter.offset.y -= 5;
			}
		}
	}

	function closeBinding()
	{
		bindingKey = false;
		bindingBlack.destroy();
		remove(bindingBlack);

		bindingText.destroy();
		remove(bindingText);

		bindingText2.destroy();
		remove(bindingText2);
		Save.toggleVolumeKeys(true);
	}

	function updateTextFrom(option:Option) {
		if(option.type == BUTTON) return;
		if(option.type == KEYBIND)
		{
			updateBind(option);
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}
	
	var silentSelection:Bool = false;
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter();
		descText.y += 270;

		for (num => item in grpOptions.members)
		{
			item.alpha = num == curSelected ? 1 : 0.6;
			var valueText:Alphabet = valueTexts.get(num);
			if (valueText != null) valueText.alpha = item.alpha;
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();
		descBox.visible = descText.text.length > 0;

		curOption = optionsArray[curSelected];
		if (!silentSelection) FunkinSound.playOnce('scrollMenu');
	}

	function reloadCheckboxes()
		for (index => checkbox in checkboxes)
			checkbox.currentValue = Std.string(optionsArray[index].getValue()) == 'true';
}