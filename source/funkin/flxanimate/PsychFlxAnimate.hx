package funkin.flxanimate;

import flixel.util.FlxDestroyUtil;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.AnimationData;
import flxanimate.FlxAnimate as OriginalFlxAnimate;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxSignal.FlxTypedSignal;

enum AtlasAlign
{
	NONE;
	TOP_LEFT;
	TOP_RIGHT(width:Float);
	CENTER;
}

class PsychFlxAnimate extends OriginalFlxAnimate
{
	static var measureCamera:FlxCamera;

	public var applyStageMatrix(default, null):Bool = false;
	public var onAnimationComplete:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
	public var animationName(default, null):String = null;
	public var align:AtlasAlign = NONE;
	public var frameLabels(default, null):Array<String> = [];

	var loopedAnims:Map<String, Bool> = [];
	var registeredLabels:Map<String, Bool> = [];
	var aligned:Bool = false;
	var listening:Bool = false;

	public function loadSpritemaps(images:Array<FlxGraphic>, spritemaps:Array<String>, animJson:Dynamic)
	{
		if (images == null || images.length < 1) return;
		loadAtlasEx(images[0], spritemaps[0], animJson);
		if (images.length < 2) return;
		var merged:FlxAnimateFrames = new FlxAnimateFrames();
		for (i in 0...images.length)
		{
			if (images[i] == null || spritemaps[i] == null) continue;
			var parsed:Dynamic = haxe.Json.parse(_removeBOM(spritemaps[i]));
			var parsedFrames = FlxAnimateFrames.fromSpriteMap(cast parsed, images[i]);
			if (parsedFrames != null) merged.addAtlas(parsedFrames);
		}
		if (merged.frames.length > 0) frames = merged;
	}

	public function setupLabels(applyStage:Bool = false):Array<String>
	{
		applyStageMatrix = applyStage;
		frameLabels = [];
		registeredLabels.clear();
		listen();
		if (anim == null || anim.stageInstance == null) return frameLabels;
		var stageX:Float = 0;
		var stageY:Float = 0;
		if (applyStage && anim.stageInstance.matrix != null)
		{
			stageX = anim.stageInstance.matrix.tx;
			stageY = anim.stageInstance.matrix.ty;
		}
		try
		{
			for (frame in anim.getFrameLabels())
			{
				if (frame == null || frame.name == null || registeredLabels.exists(frame.name)) continue;
				anim.addByFrameLabel(frame.name, frame.name, 0, false, stageX, stageY);
				registeredLabels.set(frame.name, true);
				frameLabels.push(frame.name);
			}
		}
		catch (e:Dynamic) {}
		return frameLabels;
	}

	public function hasAnimation(name:String):Bool
	{
		if (name == null || anim == null) return false;
		if (registeredLabels.exists(name) || anim.existsByName(name)) return true;
		return anim.symbolDictionary != null && anim.symbolDictionary.exists(name);
	}

	public function playAnimation(name:String, restart:Bool = true, reverse:Bool = false, loop:Bool = false, startFrame:Int = 0):Bool
	{
		if (!hasAnimation(name)) return false;
		listen();
		animationName = name;
		loopedAnims.set(name, loop);
		anim.play(name, restart, reverse, startFrame);
		return true;
	}

	public function playTimeline(loop:Bool = true)
	{
		listen();
		animationName = '';
		loopedAnims.set('', loop);
		anim.play('', true);
	}

	public function isAnimationFinished():Bool
		return anim == null || !anim.isPlaying;

	function listen()
	{
		if (listening || anim == null) return;
		listening = true;
		anim.onComplete.add(handleComplete);
	}

	function handleComplete()
	{
		var name:String = animationName;
		if (name == null) return;
		if (anim.isPlaying && name != '') return;
		if (loopedAnims.get(name) == true)
		{
			anim.play(name, true);
			return;
		}
		onAnimationComplete.dispatch(name);
	}

	public function realign()
		aligned = false;

	function measureBounds()
	{
		if (measureCamera == null) measureCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		var previous:Array<FlxCamera> = _cameras;
		cameras = [measureCamera];
		super.draw();
		_cameras = previous;
		@:privateAccess measureCamera.clearDrawStack();

		if (width <= 0 && height <= 0) return;
		switch (align)
		{
			case TOP_LEFT:
				x -= relativeX;
				y -= relativeY;
			case TOP_RIGHT(target):
				x -= relativeX + width - target;
				y -= relativeY;
			case CENTER:
				x -= relativeX + width / 2;
				y -= relativeY + height / 2;
			case NONE:
		}
	}

	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;
		if(myJson is String)
		{
			var trimmed:String = pathOrStr.trim();
			trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

			if(trimmed == '.json') myJson = File.getContent(myJson); //is a path
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(trimmed == '.json') //Path is json
		{
			myData = File.getContent(pathOrStr);
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = File.getContent(pathOrStr);
			isXml = true;
		}
		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(animJson);
		if(!isXml) frames = FlxAnimateFrames.fromSpriteMap(cast myData, img);
		else frames = FlxAnimateFrames.fromSparrow(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		if (!aligned && align != NONE && visible && alpha > 0)
		{
			aligned = true;
			measureBounds();
		}
		super.draw();
	}

	override function destroy()
	{
		onAnimationComplete.removeAll();
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.curInstance = FlxDestroyUtil.destroy(anim.curInstance);
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			//anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
			anim.metadata.destroy();
			anim.symbolDictionary = null;
		}
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}