package funkin.save;

import haxe.Serializer;
import haxe.Unserializer;
import flixel.util.FlxSave;

class SaveFile
{
	public static inline final EXTENSION:String = '.sav';
	public static inline final BACKUP_EXTENSION:String = '.bak';

	public var name(default, null):String;
	public var data:Dynamic = {};
	public var loaded(default, null):Bool = false;

	#if !sys
	var storage:FlxSave;
	#end

	public function new(name:String)
	{
		this.name = name;
	}

	public static function directory():String
	{
		#if sys
		var root:String = lime.system.System.applicationStorageDirectory;
		if (root == null || root.length == 0) root = Sys.getCwd();
		return haxe.io.Path.join([root, 'save']);
		#else
		return '';
		#end
	}

	public function path():String
		return haxe.io.Path.join([directory(), name + EXTENSION]);

	public function exists():Bool
	{
		#if sys
		return FileSystem.exists(path()) || FileSystem.exists(path() + BACKUP_EXTENSION);
		#else
		var probe:FlxSave = new FlxSave();
		probe.bind('save_$name', CoolUtil.getSavePath());
		return !probe.isEmpty();
		#end
	}

	public function load():Bool
	{
		loaded = false;
		#if sys
		for (file in [path(), path() + BACKUP_EXTENSION])
		{
			if (!FileSystem.exists(file)) continue;
			var decoded:Dynamic = decode(File.getContent(file));
			if (decoded != null)
			{
				data = decoded;
				loaded = true;
				return true;
			}
		}
		data = {};
		return false;
		#else
		storage = new FlxSave();
		storage.bind('save_$name', CoolUtil.getSavePath());
		var decoded:Dynamic = storage.data.content != null ? decode(storage.data.content) : null;
		data = decoded != null ? decoded : {};
		loaded = decoded != null;
		return loaded;
		#end
	}

	public function flush():Bool
	{
		var content:String = encode(data);
		if (content == null) return false;
		#if sys
		try
		{
			var dir:String = directory();
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			var target:String = path();
			var temp:String = target + '.tmp';
			File.saveContent(temp, content);
			if (FileSystem.exists(target)) File.copy(target, target + BACKUP_EXTENSION);
			File.copy(temp, target);
			FileSystem.deleteFile(temp);
			return true;
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Could not write save "$name": $e');
			return false;
		}
		#else
		if (storage == null)
		{
			storage = new FlxSave();
			storage.bind('save_$name', CoolUtil.getSavePath());
		}
		storage.data.content = content;
		return storage.flush();
		#end
	}

	public function erase()
	{
		data = {};
		#if sys
		for (file in [path(), path() + BACKUP_EXTENSION])
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		#else
		if (storage != null) storage.erase();
		#end
	}

	public inline function has(key:String):Bool
		return Reflect.hasField(data, key);

	public function get(key:String, ?fallback:Dynamic):Dynamic
	{
		var value:Dynamic = Reflect.field(data, key);
		return value != null ? value : fallback;
	}

	public inline function set(key:String, value:Dynamic):Dynamic
	{
		Reflect.setField(data, key, value);
		return value;
	}

	public inline function remove(key:String):Bool
		return Reflect.deleteField(data, key);

	public function importFrom(source:Dynamic, ?overwrite:Bool = false)
	{
		if (source == null) return;
		for (key in Reflect.fields(source))
			if (overwrite || !has(key)) set(key, Reflect.field(source, key));
	}

	static function encode(value:Dynamic):String
	{
		try
		{
			var serializer:Serializer = new Serializer();
			serializer.useCache = true;
			serializer.serialize(value);
			return serializer.toString();
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function decode(content:String):Dynamic
	{
		if (content == null || content.length == 0) return null;
		try
		{
			return new Unserializer(content).unserialize();
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
}
