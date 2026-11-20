#include "funkin_optimize.h"

#include <algorithm>
#include <array>
#include <cmath>

namespace funkin_optimize
{
	namespace
	{
		constexpr int kCapacity = 240;

		struct FrameStats
		{
			std::array<double, kCapacity> frames{};
			std::array<double, kCapacity> work{};
			int count = 0;
			int head = 0;
			double lastBegin = -1.0;
			double currentBegin = -1.0;
			double targetFps = 60.0;
			long long hintTarget = 0;

			void push(double frame, double busy)
			{
				frames[head] = frame;
				work[head] = busy;
				head = (head + 1) % kCapacity;
				if (count < kCapacity) count++;
			}
		};

		FrameStats &stats()
		{
			static FrameStats instance;
			return instance;
		}

		double mean(const std::array<double, kCapacity> &values, int count)
		{
			if (count <= 0) return 0.0;
			double sum = 0.0;
			for (int i = 0; i < count; i++) sum += values[i];
			return sum / count;
		}
	}

	void frameBegin()
	{
		FrameStats &s = stats();
		double now = fo_now();
		s.currentBegin = now;
	}

	void frameEnd()
	{
		FrameStats &s = stats();
		if (s.currentBegin < 0) return;
		double now = fo_now();
		double busy = now - s.currentBegin;
		double frame = s.lastBegin >= 0 ? s.currentBegin - s.lastBegin : busy;
		s.lastBegin = s.currentBegin;
		s.currentBegin = -1.0;
		if (frame > 0 && frame < 1.0) s.push(frame, busy);
		if (busy > 0) fo_hint_report(static_cast<long long>(busy * 1e9));
	}

	void setTargetFps(double fps)
	{
		FrameStats &s = stats();
		if (fps <= 0) return;
		s.targetFps = fps;
		long long target = static_cast<long long>(1e9 / fps);
		if (target == s.hintTarget) return;
		s.hintTarget = target;
		if (fo_hint_active()) fo_hint_target(target);
		else fo_hint_open(target);
	}

	void reset()
	{
		FrameStats &s = stats();
		s.count = 0;
		s.head = 0;
		s.lastBegin = -1.0;
		s.currentBegin = -1.0;
	}

	double averageFrameMs()
	{
		FrameStats &s = stats();
		return mean(s.frames, s.count) * 1000.0;
	}

	double averageWorkMs()
	{
		FrameStats &s = stats();
		return mean(s.work, s.count) * 1000.0;
	}

	double averageFps()
	{
		double ms = averageFrameMs();
		return ms > 0 ? 1000.0 / ms : 0.0;
	}

	double lowFps()
	{
		FrameStats &s = stats();
		if (s.count <= 0) return 0.0;
		std::array<double, kCapacity> sorted = s.frames;
		std::sort(sorted.begin(), sorted.begin() + s.count, [](double a, double b) { return a > b; });
		int slice = std::max(1, s.count / 100);
		double sum = 0.0;
		for (int i = 0; i < slice; i++) sum += sorted[i];
		double worst = sum / slice;
		return worst > 0 ? 1.0 / worst : 0.0;
	}

	double jitterMs()
	{
		FrameStats &s = stats();
		if (s.count < 2) return 0.0;
		double average = mean(s.frames, s.count);
		double variance = 0.0;
		for (int i = 0; i < s.count; i++)
		{
			double delta = s.frames[i] - average;
			variance += delta * delta;
		}
		return std::sqrt(variance / s.count) * 1000.0;
	}

	int samples()
	{
		return stats().count;
	}
}
