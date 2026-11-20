package funkin.shaders;

import flixel.system.FlxAssets.FlxShader;

class AngleMask extends FlxShader
{
	public var extraColor(default, set):FlxColor = 0xFFFFFFFF;

	function set_extraColor(value:FlxColor):FlxColor
	{
		extraTint.value = [value.redFloat, value.greenFloat, value.blueFloat];
		return extraColor = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec3 extraTint;
		uniform vec2 endPosition;

		vec2 hash22(vec2 p) {
			vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
			p3 += dot(p3, p3.yzx + 33.33);
			return fract((p3.xx + p3.yz) * p3.zy);
		}

		vec4 mainPass(vec2 fragCoord) {
			vec4 base = flixel_texture2D(bitmap, fragCoord);
			vec2 uv = fragCoord.xy;
			vec2 start = vec2(0.0, 0.0);
			vec2 end = vec2(endPosition.x / openfl_TextureSize.x, 1.0);
			float angle = atan(end.y - start.y, end.x - start.x);
			uv -= start;
			if (atan(uv.y, uv.x) < angle)
				return base;
			return vec4(0.0);
		}

		vec4 antialias(vec2 fragCoord) {
			const float AA_STAGES = 2.0;
			const float AA_TOTAL_PASSES = AA_STAGES * AA_STAGES + 1.0;
			const float AA_JITTER = 0.5;
			vec4 color = mainPass(fragCoord);
			for (float x = 0.0; x < AA_STAGES; x++)
			{
				for (float y = 0.0; y < AA_STAGES; y++)
				{
					vec2 offset = AA_JITTER * (2.0 * hash22(vec2(x, y)) - 1.0) / openfl_TextureSize.xy;
					color += mainPass(fragCoord + offset);
				}
			}
			return color / AA_TOTAL_PASSES;
		}

		void main() {
			vec4 col = antialias(openfl_TextureCoordv);
			col.xyz = col.xyz * extraTint.xyz;
			gl_FragColor = col;
		}
	')
	public function new()
	{
		super();
		endPosition.value = [90, 100];
		extraTint.value = [1, 1, 1];
	}
}
