#if !macro
//Discord API
#if DISCORD_ALLOWED
import funkin.api.discord.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import funkin.data.achievements.Achievements;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import funkin.assets.Paths;
import funkin.audio.FunkinSound;
import funkin.input.Controls;
import funkin.util.CoolUtil;
import funkin.util.math.MathUtil;
import funkin.ui.MusicBeatState;
import funkin.ui.MusicBeatSubstate;
import funkin.ui.transition.CustomFadeTransition;
import funkin.save.Save;
import funkin.util.FPSManager;
import funkin.play.Conductor;
import funkin.play.stages.BaseStage;
import funkin.data.song.Difficulty;
import funkin.modding.Mods;
import funkin.data.level.LevelData;
import funkin.data.language.Language;

import funkin.ui.psych.*;

import funkin.ui.text.Alphabet;
import funkin.graphics.BGSprite;

import funkin.play.PlayState;
import funkin.ui.transition.LoadingState;

#if flxanimate
import flxanimate.*;
import funkin.flxanimate.PsychFlxAnimate as FlxAnimate;
#end

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end
