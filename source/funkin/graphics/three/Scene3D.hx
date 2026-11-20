package funkin.graphics.three;

#if foxlite
import foxlite.FoxCamera;
import foxlite.FoxModel;
import foxlite.FoxObject;
import foxlite.FoxScene;
import foxlite.group.FoxObjectGroup;
import foxlite.lights.FoxDirectionalLight;
import foxlite.lights.FoxPointLight;
import foxlite.loaders.FoxGLTFLoader;
import foxlite.loaders.FoxOBJLoader;
import foxlite.material.FoxMaterial;
import foxlite.mesh.FoxCubeMesh;
import foxlite.renderer.FoxRenderer;
import foxlite.texture.FoxTexture;
import funkin.data.DataUtil;

class Scene3D extends FoxScene
{
	public var camera3D(default, null):FoxCamera;
	public var objects(default, null):Map<String, FoxObject> = [];

	public function new(width:Int = 0, height:Int = 0, ?cameraPosition:Array<Float>, fov:Float = 60)
	{
		Foxlite.init();
		super(width > 0 ? width : FlxG.width, height > 0 ? height : FlxG.height);
		var position:Array<Float> = cameraPosition != null ? cameraPosition : [0, 0, 5];
		camera3D = new FoxCamera(position[0], position[1], position.length > 2 ? position[2] : 5);
		camera3D.fov = fov;
		camera3D.near = 0.05;
		camera3D.far = 1000;
		foxCameras.push(camera3D);
		add(camera3D);
	}

	public static function fromData(data:Dynamic):Scene3D
	{
		var size:Array<Float> = DataUtil.vector(data.size, FlxG.width, FlxG.height);
		var cam:Dynamic = data.camera != null ? data.camera : {};
		var scene:Scene3D = new Scene3D(Std.int(size[0]), Std.int(size[1]), DataUtil.vector3(cam.position, 0, 0, 5), DataUtil.toFloat(cam.fov, 60));
		if (cam.rotation != null)
		{
			var rotation:Array<Float> = DataUtil.vector3(cam.rotation);
			scene.camera3D.setRotation(rotation[0], rotation[1], rotation[2]);
		}
		if (cam.background != null) scene.camera3D.bgColor = funkin.data.ui.UIData.parseColor(cam.background, 0x00000000);

		var position:Array<Float> = DataUtil.vector(data.position);
		scene.setPosition(position[0], position[1]);

		for (light in DataUtil.array(data.lights)) scene.addLightFromData(light);
		for (entry in DataUtil.array(data.models))
		{
			var object:FoxObject = entry.cube != null ? scene.addCube(entry.name, DataUtil.toFloat(entry.cube, 1), entry.texture) : scene.addModel(entry.name, Std.string(entry.file));
			if (object == null) continue;
			scene.applyTransform(object, entry);
			if (entry.animation != null) scene.playAnimation(entry.name, Std.string(entry.animation));
			if (entry.spin != null) scene.spin.set(entry.name, DataUtil.vector3(entry.spin));
		}
		return scene;
	}

	public var spin(default, null):Map<String, Array<Float>> = [];

	override function update(elapsed:Float)
	{
		for (name => speed in spin)
		{
			var object:FoxObject = objects.get(name);
			if (object == null) continue;
			object.rotation.x += speed[0] * elapsed;
			object.rotation.y += speed[1] * elapsed;
			object.rotation.z += speed[2] * elapsed;
		}
		super.update(elapsed);
	}

	public function addModel(name:String, file:String):FoxObject
	{
		if (file == null) return null;
		var lower:String = file.toLowerCase();
		var object:FoxObject = null;
		if (lower.endsWith('.glb') || lower.endsWith('.gltf'))
		{
			var data:GLTFData = lower.endsWith('.glb') ? FoxGLTFLoader.loadBinary(file) : FoxGLTFLoader.load(file);
			if (data == null || data.scenes == null || data.scenes.length < 1) return null;
			object = data.scenes[0];
		}
		else if (lower.endsWith('.obj'))
		{
			var data = FoxOBJLoader.load(file);
			if (data == null) return null;
			var model:FoxModel = new FoxModel();
			for (mesh in data.meshes) model.addMesh(mesh);
			object = model;
		}
		if (object == null) return null;
		register(name, object);
		return object;
	}

	public function addCube(name:String, size:Float = 1, ?texture:String):FoxObject
	{
		var material = FoxMaterial.createBasic();
		var tex:FoxTexture = texture != null ? FoxTexture.fromImageRaw(Foxlite.resolve('images/$texture.png', IMAGE)) : null;
		material.textures.set('bitmap', tex != null ? tex : FoxRenderer.MISSING_TEXTURE);
		var model:FoxModel = new FoxModel();
		model.addMesh(new FoxCubeMesh(size, size, size, material));
		register(name, model);
		return model;
	}

	public function addLightFromData(data:Dynamic):FoxObject
	{
		if (data == null) return null;
		var position:Array<Float> = DataUtil.vector3(data.position, 0, 5, 5);
		var color:FlxColor = funkin.data.ui.UIData.parseColor(data.color, FlxColor.WHITE);
		var energy:Float = DataUtil.toFloat(data.energy, 1);
		var light:FoxObject = switch (Std.string(data.type))
		{
			case 'point': new FoxPointLight(position[0], position[1], position[2], color, energy, DataUtil.toFloat(data.range, 5));
			default: new FoxDirectionalLight(position[0], position[1], position[2], color, energy, DataUtil.toBool(data.shadow));
		}
		if (data.rotation != null)
		{
			var rotation:Array<Float> = DataUtil.vector3(data.rotation);
			light.setRotation(rotation[0], rotation[1], rotation[2]);
		}
		register(data.name, light);
		return light;
	}

	public function register(name:Dynamic, object:FoxObject)
	{
		if (name != null) objects.set(Std.string(name), object);
		add(object);
	}

	public function applyTransform(object:FoxObject, data:Dynamic)
	{
		var position:Array<Float> = DataUtil.vector3(data.position);
		var rotation:Array<Float> = DataUtil.vector3(data.rotation);
		var scale:Array<Float> = DataUtil.vector3(data.scale, 1, 1, 1);
		object.setPosition(position[0], position[1], position[2]);
		object.setRotation(rotation[0], rotation[1], rotation[2]);
		object.setScale(scale[0], scale[1], scale[2]);
	}

	public function getObject(name:String):FoxObject
		return objects.get(name);

	public function playAnimation(name:String, animation:String, ?from:Float):Bool
	{
		var object:FoxObject = objects.get(name);
		if (object == null || !Std.isOfType(object, FoxObjectGroup)) return false;
		var group:FoxObjectGroup = cast object;
		if (group.animation == null || group.animation.getAnimation(animation) == null) return false;
		group.animation.play(animation, from);
		return true;
	}
}
#end
