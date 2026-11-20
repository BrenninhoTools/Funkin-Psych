#ifndef FUNKIN_OPTIMIZE_H
#define FUNKIN_OPTIMIZE_H

#ifdef __cplusplus
extern "C" {
#endif

#define FO_VERSION "1.0.0"

#define FO_THERMAL_UNKNOWN -1
#define FO_THERMAL_NONE 0
#define FO_THERMAL_LIGHT 1
#define FO_THERMAL_MODERATE 2
#define FO_THERMAL_SEVERE 3
#define FO_THERMAL_CRITICAL 4
#define FO_THERMAL_EMERGENCY 5
#define FO_THERMAL_SHUTDOWN 6

#define FO_FEATURE_TIMER 1
#define FO_FEATURE_PRIORITY 2
#define FO_FEATURE_POWER 4
#define FO_FEATURE_AFFINITY 8
#define FO_FEATURE_HINTS 16
#define FO_FEATURE_THERMAL 32

int fo_init(int pin_big_cores);
void fo_shutdown(void);
int fo_features(void);
const char *fo_platform(void);

double fo_now(void);
void fo_sleep(double seconds);

int fo_cpu_count(void);
int fo_big_core_count(void);
int fo_pin_big_cores(void);
void fo_unpin_cores(void);

long long fo_total_memory(void);
long long fo_available_memory(void);
long long fo_process_memory(void);
int fo_trim_memory(void);

int fo_thermal_status(void);

int fo_hint_open(long long target_ns);
void fo_hint_target(long long target_ns);
void fo_hint_report(long long actual_ns);
void fo_hint_close(void);
int fo_hint_active(void);

#ifdef __cplusplus
}

namespace funkin_optimize
{
	void frameBegin();
	void frameEnd();
	void setTargetFps(double fps);
	void reset();
	double averageFps();
	double lowFps();
	double averageFrameMs();
	double averageWorkMs();
	double jitterMs();
	int samples();
}
#endif

#endif
