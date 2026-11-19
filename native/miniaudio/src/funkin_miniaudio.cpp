#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_GENERATION
#if defined(__APPLE__)
#define MA_NO_RUNTIME_LINKING
#endif
#include "miniaudio.h"
#include "funkin_miniaudio.h"

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <vector>

namespace
{
	struct PeakNode
	{
		ma_node_base base;
		float peak;
	};

	void peakProcess(ma_node* node, const float** framesIn, ma_uint32* frameCountIn, float** framesOut, ma_uint32* frameCountOut)
	{
		PeakNode* self = (PeakNode*)node;
		ma_uint32 channels = ma_node_get_output_channels(node, 0);
		ma_uint32 count = *frameCountIn < *frameCountOut ? *frameCountIn : *frameCountOut;
		float peak = 0.0f;
		const float* input = framesIn[0];
		float* output = framesOut[0];
		for (ma_uint32 i = 0; i < count * channels; i++)
		{
			float value = input[i];
			output[i] = value;
			float magnitude = value < 0 ? -value : value;
			if (magnitude > peak) peak = magnitude;
		}
		self->peak = peak;
		*frameCountIn = count;
		*frameCountOut = count;
	}

	ma_node_vtable peakVTable = {peakProcess, NULL, 1, 1, 0};

	struct Sound
	{
		ma_sound sound;
		ma_decoder decoder;
		PeakNode tap;
		unsigned char* memory;
		bool hasDecoder;
		bool hasTap;
	};

	ma_engine engine;
	bool engineActive = false;
	std::vector<Sound*> sounds;
	std::mutex lock;

	Sound* find(int id)
	{
		if (id < 0 || id >= (int)sounds.size()) return NULL;
		return sounds[id];
	}

	int store(Sound* sound)
	{
		for (size_t i = 0; i < sounds.size(); i++)
		{
			if (sounds[i] == NULL)
			{
				sounds[i] = sound;
				return (int)i;
			}
		}
		sounds.push_back(sound);
		return (int)sounds.size() - 1;
	}

	void attachTap(Sound* sound)
	{
		ma_uint32 channels = ma_engine_get_channels(&engine);
		ma_node_config config = ma_node_config_init();
		config.vtable = &peakVTable;
		config.pInputChannels = &channels;
		config.pOutputChannels = &channels;
		sound->tap.peak = 0.0f;
		if (ma_node_init(ma_engine_get_node_graph(&engine), &config, NULL, &sound->tap) != MA_SUCCESS) return;
		ma_node_attach_output_bus(&sound->tap, 0, ma_engine_get_endpoint(&engine), 0);
		ma_node_attach_output_bus(&sound->sound, 0, &sound->tap, 0);
		sound->hasTap = true;
	}

	void destroy(Sound* sound)
	{
		if (sound == NULL) return;
		ma_sound_uninit(&sound->sound);
		if (sound->hasTap) ma_node_uninit(&sound->tap, NULL);
		if (sound->hasDecoder) ma_decoder_uninit(&sound->decoder);
		if (sound->memory != NULL) free(sound->memory);
		delete sound;
	}

	float sampleAt(const unsigned char* data, int bitsPerSample, int index)
	{
		switch (bitsPerSample)
		{
			case 8: return ((int)data[index] - 128) / 128.0f;
			case 16:
			{
				short value;
				memcpy(&value, data + index * 2, 2);
				return value / 32768.0f;
			}
			case 24:
			{
				const unsigned char* p = data + index * 3;
				int value = (p[0] << 8) | (p[1] << 16) | (p[2] << 24);
				return (value >> 8) / 8388608.0f;
			}
			case 32:
			{
				float value;
				memcpy(&value, data + index * 4, 4);
				return value;
			}
		}
		return 0.0f;
	}
}

namespace funkin_miniaudio
{
	const char* version()
	{
		return ma_version_string();
	}

	bool engineInit()
	{
		std::lock_guard<std::mutex> guard(lock);
		if (engineActive) return true;
		ma_engine_config config = ma_engine_config_init();
		engineActive = ma_engine_init(&config, &engine) == MA_SUCCESS;
		return engineActive;
	}

	void engineShutdown()
	{
		std::lock_guard<std::mutex> guard(lock);
		if (!engineActive) return;
		for (size_t i = 0; i < sounds.size(); i++)
		{
			destroy(sounds[i]);
			sounds[i] = NULL;
		}
		sounds.clear();
		ma_engine_uninit(&engine);
		engineActive = false;
	}

	bool engineReady()
	{
		return engineActive;
	}

	void setMasterVolume(float volume)
	{
		if (engineActive) ma_engine_set_volume(&engine, volume);
	}

	float getMasterVolume()
	{
		return engineActive ? ma_engine_get_volume(&engine) : 0.0f;
	}

	int engineSampleRate()
	{
		return engineActive ? (int)ma_engine_get_sample_rate(&engine) : 0;
	}

	int engineChannels()
	{
		return engineActive ? (int)ma_engine_get_channels(&engine) : 0;
	}

	int soundLoadFile(const char* path, bool stream)
	{
		if (!engineInit() || path == NULL) return -1;
		std::lock_guard<std::mutex> guard(lock);
		Sound* sound = new Sound();
		memset(sound, 0, sizeof(Sound));
		ma_uint32 flags = MA_SOUND_FLAG_NO_SPATIALIZATION | MA_SOUND_FLAG_NO_DEFAULT_ATTACHMENT;
		if (stream) flags |= MA_SOUND_FLAG_STREAM;
		else flags |= MA_SOUND_FLAG_DECODE;
		if (ma_sound_init_from_file(&engine, path, flags, NULL, NULL, &sound->sound) != MA_SUCCESS)
		{
			delete sound;
			return -1;
		}
		attachTap(sound);
		if (!sound->hasTap) ma_node_attach_output_bus(&sound->sound, 0, ma_engine_get_endpoint(&engine), 0);
		return store(sound);
	}

	int soundLoadMemory(const unsigned char* data, int size)
	{
		if (!engineInit() || data == NULL || size <= 0) return -1;
		std::lock_guard<std::mutex> guard(lock);
		Sound* sound = new Sound();
		memset(sound, 0, sizeof(Sound));
		sound->memory = (unsigned char*)malloc((size_t)size);
		if (sound->memory == NULL)
		{
			delete sound;
			return -1;
		}
		memcpy(sound->memory, data, (size_t)size);
		ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_f32, ma_engine_get_channels(&engine), ma_engine_get_sample_rate(&engine));
		if (ma_decoder_init_memory(sound->memory, (size_t)size, &decoderConfig, &sound->decoder) != MA_SUCCESS)
		{
			free(sound->memory);
			delete sound;
			return -1;
		}
		sound->hasDecoder = true;
		ma_uint32 flags = MA_SOUND_FLAG_NO_SPATIALIZATION | MA_SOUND_FLAG_NO_DEFAULT_ATTACHMENT;
		if (ma_sound_init_from_data_source(&engine, &sound->decoder, flags, NULL, &sound->sound) != MA_SUCCESS)
		{
			ma_decoder_uninit(&sound->decoder);
			free(sound->memory);
			delete sound;
			return -1;
		}
		attachTap(sound);
		if (!sound->hasTap) ma_node_attach_output_bus(&sound->sound, 0, ma_engine_get_endpoint(&engine), 0);
		return store(sound);
	}

	void soundRelease(int id)
	{
		std::lock_guard<std::mutex> guard(lock);
		Sound* sound = find(id);
		if (sound == NULL) return;
		destroy(sound);
		sounds[id] = NULL;
	}

	bool soundPlay(int id)
	{
		Sound* sound = find(id);
		return sound != NULL && ma_sound_start(&sound->sound) == MA_SUCCESS;
	}

	bool soundStop(int id)
	{
		Sound* sound = find(id);
		return sound != NULL && ma_sound_stop(&sound->sound) == MA_SUCCESS;
	}

	bool soundIsPlaying(int id)
	{
		Sound* sound = find(id);
		return sound != NULL && ma_sound_is_playing(&sound->sound);
	}

	void soundSetVolume(int id, float volume)
	{
		Sound* sound = find(id);
		if (sound != NULL) ma_sound_set_volume(&sound->sound, volume);
	}

	float soundGetVolume(int id)
	{
		Sound* sound = find(id);
		return sound != NULL ? ma_sound_get_volume(&sound->sound) : 0.0f;
	}

	void soundSetPan(int id, float pan)
	{
		Sound* sound = find(id);
		if (sound != NULL) ma_sound_set_pan(&sound->sound, pan);
	}

	void soundSetPitch(int id, float pitch)
	{
		Sound* sound = find(id);
		if (sound != NULL) ma_sound_set_pitch(&sound->sound, pitch);
	}

	void soundSetLooping(int id, bool looping)
	{
		Sound* sound = find(id);
		if (sound != NULL) ma_sound_set_looping(&sound->sound, looping ? MA_TRUE : MA_FALSE);
	}

	bool soundIsLooping(int id)
	{
		Sound* sound = find(id);
		return sound != NULL && ma_sound_is_looping(&sound->sound);
	}

	bool soundAtEnd(int id)
	{
		Sound* sound = find(id);
		return sound == NULL || ma_sound_at_end(&sound->sound);
	}

	void soundSeek(int id, double milliseconds)
	{
		Sound* sound = find(id);
		if (sound == NULL || !engineActive) return;
		ma_uint64 frame = (ma_uint64)(milliseconds < 0 ? 0 : milliseconds * ma_engine_get_sample_rate(&engine) / 1000.0);
		ma_sound_seek_to_pcm_frame(&sound->sound, frame);
	}

	double soundGetTime(int id)
	{
		Sound* sound = find(id);
		if (sound == NULL) return 0;
		float seconds = 0;
		ma_sound_get_cursor_in_seconds(&sound->sound, &seconds);
		return seconds * 1000.0;
	}

	double soundGetLength(int id)
	{
		Sound* sound = find(id);
		if (sound == NULL) return 0;
		float seconds = 0;
		ma_sound_get_length_in_seconds(&sound->sound, &seconds);
		return seconds * 1000.0;
	}

	float soundGetPeak(int id)
	{
		Sound* sound = find(id);
		if (sound == NULL || !sound->hasTap || !ma_sound_is_playing(&sound->sound)) return 0.0f;
		return sound->tap.peak;
	}

	float bufferPeak(const unsigned char* data, int byteLength, int bitsPerSample, int channels, int startFrame, int frameCount, int channel)
	{
		if (data == NULL || channels <= 0 || frameCount <= 0) return 0.0f;
		int bytesPerSample = bitsPerSample / 8;
		if (bytesPerSample <= 0) return 0.0f;
		int totalFrames = byteLength / (bytesPerSample * channels);
		if (startFrame < 0) startFrame = 0;
		int endFrame = startFrame + frameCount;
		if (endFrame > totalFrames) endFrame = totalFrames;
		float peak = 0.0f;
		for (int frame = startFrame; frame < endFrame; frame++)
		{
			for (int c = 0; c < channels; c++)
			{
				if (channel >= 0 && c != channel) continue;
				float value = sampleAt(data, bitsPerSample, frame * channels + c);
				if (value < 0) value = -value;
				if (value > peak) peak = value;
			}
		}
		return peak > 1.0f ? 1.0f : peak;
	}
}
