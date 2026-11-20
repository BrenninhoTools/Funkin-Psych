#if defined(__linux__) || defined(__ANDROID__)
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

#include "funkin_optimize.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <mmsystem.h>
#include <malloc.h>
#include <psapi.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <malloc/malloc.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <sched.h>
#include <sys/sysctl.h>
#include <time.h>
#include <unistd.h>
#else
#include <dlfcn.h>
#include <errno.h>
#include <malloc.h>
#include <pthread.h>
#include <sched.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>
#endif

static int fo_feature_mask = 0;
static int fo_initialized = 0;

#if defined(_WIN32)
static LARGE_INTEGER fo_frequency;
static int fo_timer_period = 0;
#elif defined(__APPLE__)
static mach_timebase_info_data_t fo_timebase;
#endif

#if defined(__ANDROID__)
typedef struct APerformanceHintManager APerformanceHintManager;
typedef struct APerformanceHintSession APerformanceHintSession;
typedef struct AThermalManager AThermalManager;
typedef APerformanceHintManager *(*fo_hint_manager_fn)(void);
typedef APerformanceHintSession *(*fo_hint_create_fn)(APerformanceHintManager *, const int *, size_t, long long);
typedef int (*fo_hint_update_fn)(APerformanceHintSession *, long long);
typedef int (*fo_hint_report_fn)(APerformanceHintSession *, long long);
typedef void (*fo_hint_close_fn)(APerformanceHintSession *);
typedef AThermalManager *(*fo_thermal_acquire_fn)(void);
typedef int (*fo_thermal_status_fn)(AThermalManager *);
typedef void (*fo_thermal_release_fn)(AThermalManager *);

static void *fo_android_lib = NULL;
static fo_hint_manager_fn fo_hint_manager = NULL;
static fo_hint_create_fn fo_hint_create = NULL;
static fo_hint_update_fn fo_hint_update = NULL;
static fo_hint_report_fn fo_hint_report_actual = NULL;
static fo_hint_close_fn fo_hint_close_session = NULL;
static fo_thermal_acquire_fn fo_thermal_acquire = NULL;
static fo_thermal_status_fn fo_thermal_get = NULL;
static fo_thermal_release_fn fo_thermal_release = NULL;
static APerformanceHintSession *fo_session = NULL;
static AThermalManager *fo_thermal = NULL;

static void fo_load_android(void)
{
	if (fo_android_lib != NULL) return;
	fo_android_lib = dlopen("libandroid.so", RTLD_NOW | RTLD_LOCAL);
	if (fo_android_lib == NULL) return;
	fo_hint_manager = (fo_hint_manager_fn)dlsym(fo_android_lib, "APerformanceHint_getManager");
	fo_hint_create = (fo_hint_create_fn)dlsym(fo_android_lib, "APerformanceHint_createSession");
	fo_hint_update = (fo_hint_update_fn)dlsym(fo_android_lib, "APerformanceHint_updateTargetWorkDuration");
	fo_hint_report_actual = (fo_hint_report_fn)dlsym(fo_android_lib, "APerformanceHint_reportActualWorkDuration");
	fo_hint_close_session = (fo_hint_close_fn)dlsym(fo_android_lib, "APerformanceHint_closeSession");
	fo_thermal_acquire = (fo_thermal_acquire_fn)dlsym(fo_android_lib, "AThermal_acquireManager");
	fo_thermal_get = (fo_thermal_status_fn)dlsym(fo_android_lib, "AThermal_getCurrentThermalStatus");
	fo_thermal_release = (fo_thermal_release_fn)dlsym(fo_android_lib, "AThermal_releaseManager");
	if (fo_hint_manager && fo_hint_create && fo_hint_report_actual && fo_hint_close_session) fo_feature_mask |= FO_FEATURE_HINTS;
	if (fo_thermal_acquire && fo_thermal_get) fo_feature_mask |= FO_FEATURE_THERMAL;
}
#endif

#if (defined(__linux__) || defined(__ANDROID__)) && !defined(__APPLE__)
static int fo_affinity_saved = 0;
static cpu_set_t fo_original_affinity;

static long fo_read_long(const char *path)
{
	FILE *file = fopen(path, "r");
	long value = -1;
	if (file == NULL) return -1;
	if (fscanf(file, "%ld", &value) != 1) value = -1;
	fclose(file);
	return value;
}

static long fo_core_frequency(int core)
{
	char path[128];
	snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq", core);
	return fo_read_long(path);
}

static pid_t fo_tid(void)
{
	return (pid_t)syscall(SYS_gettid);
}
#endif

static void fo_timer_init(void)
{
#if defined(_WIN32)
	QueryPerformanceFrequency(&fo_frequency);
#elif defined(__APPLE__)
	mach_timebase_info(&fo_timebase);
#endif
}

const char *fo_platform(void)
{
#if defined(_WIN32)
	return "windows";
#elif defined(__ANDROID__)
	return "android";
#elif defined(__APPLE__) && TARGET_OS_IPHONE
	return "ios";
#elif defined(__APPLE__)
	return "mac";
#elif defined(__linux__)
	return "linux";
#else
	return "unknown";
#endif
}

int fo_init(int pin_big_cores)
{
	if (fo_initialized) return fo_feature_mask;
	fo_initialized = 1;
	fo_timer_init();
	fo_feature_mask |= FO_FEATURE_TIMER;

#if defined(_WIN32)
	if (timeBeginPeriod(1) == TIMERR_NOERROR) fo_timer_period = 1;
	if (SetPriorityClass(GetCurrentProcess(), ABOVE_NORMAL_PRIORITY_CLASS)) fo_feature_mask |= FO_FEATURE_PRIORITY;
	SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);
	{
		typedef BOOL(WINAPI * SetProcessInformationFn)(HANDLE, int, LPVOID, DWORD);
		HMODULE kernel = GetModuleHandleA("kernel32.dll");
		SetProcessInformationFn setInfo = kernel ? (SetProcessInformationFn)GetProcAddress(kernel, "SetProcessInformation") : NULL;
		if (setInfo != NULL)
		{
			struct
			{
				ULONG Version;
				ULONG ControlMask;
				ULONG StateMask;
			} state;
			state.Version = 1;
			state.ControlMask = 1;
			state.StateMask = 0;
			if (setInfo(GetCurrentProcess(), 4, &state, sizeof(state))) fo_feature_mask |= FO_FEATURE_POWER;
		}
	}
#elif defined(__APPLE__)
	if (pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0) == 0) fo_feature_mask |= FO_FEATURE_PRIORITY;
#else
	if (setpriority(PRIO_PROCESS, (id_t)fo_tid(), -4) == 0) fo_feature_mask |= FO_FEATURE_PRIORITY;
#if defined(__ANDROID__)
	fo_load_android();
#endif
	if (pin_big_cores && fo_pin_big_cores()) fo_feature_mask |= FO_FEATURE_AFFINITY;
#endif
	(void)pin_big_cores;
	return fo_feature_mask;
}

void fo_shutdown(void)
{
	if (!fo_initialized) return;
	fo_hint_close();
#if defined(_WIN32)
	if (fo_timer_period) timeEndPeriod(1);
	fo_timer_period = 0;
#endif
#if defined(__ANDROID__)
	if (fo_thermal != NULL && fo_thermal_release != NULL) fo_thermal_release(fo_thermal);
	fo_thermal = NULL;
#endif
	fo_unpin_cores();
	fo_initialized = 0;
	fo_feature_mask = 0;
}

int fo_features(void)
{
	return fo_feature_mask;
}

double fo_now(void)
{
#if defined(_WIN32)
	LARGE_INTEGER counter;
	if (fo_frequency.QuadPart == 0) QueryPerformanceFrequency(&fo_frequency);
	QueryPerformanceCounter(&counter);
	return (double)counter.QuadPart / (double)fo_frequency.QuadPart;
#elif defined(__APPLE__)
	if (fo_timebase.denom == 0) mach_timebase_info(&fo_timebase);
	return (double)mach_absolute_time() * (double)fo_timebase.numer / (double)fo_timebase.denom / 1e9;
#else
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	return (double)now.tv_sec + (double)now.tv_nsec / 1e9;
#endif
}

void fo_sleep(double seconds)
{
	double end;
	if (seconds <= 0) return;
	end = fo_now() + seconds;
	while (1)
	{
		double remaining = end - fo_now();
		if (remaining <= 0) break;
		if (remaining > 0.002)
		{
			double chunk = remaining - 0.0015;
#if defined(_WIN32)
			Sleep((DWORD)(chunk * 1000.0));
#else
			struct timespec request;
			request.tv_sec = (time_t)chunk;
			request.tv_nsec = (long)((chunk - (double)request.tv_sec) * 1e9);
			nanosleep(&request, NULL);
#endif
		}
		else
		{
#if defined(_WIN32)
			YieldProcessor();
#elif defined(__APPLE__)
			sched_yield();
#else
			sched_yield();
#endif
		}
	}
}

int fo_cpu_count(void)
{
#if defined(_WIN32)
	SYSTEM_INFO info;
	GetSystemInfo(&info);
	return (int)info.dwNumberOfProcessors;
#else
	long count = sysconf(_SC_NPROCESSORS_CONF);
	return count > 0 ? (int)count : 1;
#endif
}

int fo_big_core_count(void)
{
#if (defined(__linux__) || defined(__ANDROID__)) && !defined(__APPLE__)
	int count = fo_cpu_count();
	long highest = 0;
	int big = 0;
	int i;
	for (i = 0; i < count; i++)
	{
		long frequency = fo_core_frequency(i);
		if (frequency > highest) highest = frequency;
	}
	if (highest <= 0) return count;
	for (i = 0; i < count; i++)
		if (fo_core_frequency(i) >= highest * 3 / 4) big++;
	return big > 0 ? big : count;
#elif defined(__APPLE__)
	int value = 0;
	size_t size = sizeof(value);
	if (sysctlbyname("hw.perflevel0.physicalcpu", &value, &size, NULL, 0) == 0 && value > 0) return value;
	return fo_cpu_count();
#else
	return fo_cpu_count();
#endif
}

int fo_pin_big_cores(void)
{
#if (defined(__linux__) || defined(__ANDROID__)) && !defined(__APPLE__)
	int count = fo_cpu_count();
	long highest = 0;
	int chosen = 0;
	int i;
	cpu_set_t mask;
	if (count < 4) return 0;
	for (i = 0; i < count; i++)
	{
		long frequency = fo_core_frequency(i);
		if (frequency > highest) highest = frequency;
	}
	if (highest <= 0) return 0;
	CPU_ZERO(&mask);
	for (i = 0; i < count && i < CPU_SETSIZE; i++)
	{
		if (fo_core_frequency(i) >= highest * 3 / 4)
		{
			CPU_SET(i, &mask);
			chosen++;
		}
	}
	if (chosen < 2 || chosen == count) return 0;
	if (!fo_affinity_saved)
	{
		if (sched_getaffinity(0, sizeof(fo_original_affinity), &fo_original_affinity) != 0) return 0;
		fo_affinity_saved = 1;
	}
	return sched_setaffinity(0, sizeof(mask), &mask) == 0;
#else
	return 0;
#endif
}

void fo_unpin_cores(void)
{
#if (defined(__linux__) || defined(__ANDROID__)) && !defined(__APPLE__)
	if (!fo_affinity_saved) return;
	sched_setaffinity(0, sizeof(fo_original_affinity), &fo_original_affinity);
	fo_affinity_saved = 0;
#endif
}

long long fo_total_memory(void)
{
#if defined(_WIN32)
	MEMORYSTATUSEX status;
	status.dwLength = sizeof(status);
	return GlobalMemoryStatusEx(&status) ? (long long)status.ullTotalPhys : -1;
#elif defined(__APPLE__)
	long long value = 0;
	size_t size = sizeof(value);
	return sysctlbyname("hw.memsize", &value, &size, NULL, 0) == 0 ? value : -1;
#else
	long pages = sysconf(_SC_PHYS_PAGES);
	long page = sysconf(_SC_PAGESIZE);
	return pages > 0 && page > 0 ? (long long)pages * page : -1;
#endif
}

long long fo_available_memory(void)
{
#if defined(_WIN32)
	MEMORYSTATUSEX status;
	status.dwLength = sizeof(status);
	return GlobalMemoryStatusEx(&status) ? (long long)status.ullAvailPhys : -1;
#elif defined(__APPLE__)
	vm_statistics64_data_t stats;
	mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
	vm_size_t page = 0;
	if (host_page_size(mach_host_self(), &page) != KERN_SUCCESS) return -1;
	if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&stats, &count) != KERN_SUCCESS) return -1;
	return (long long)(stats.free_count + stats.inactive_count) * (long long)page;
#else
	FILE *file = fopen("/proc/meminfo", "r");
	char line[256];
	long long value = -1;
	if (file != NULL)
	{
		while (fgets(line, sizeof(line), file) != NULL)
		{
			long long kb;
			if (sscanf(line, "MemAvailable: %lld kB", &kb) == 1)
			{
				value = kb * 1024;
				break;
			}
		}
		fclose(file);
	}
	if (value < 0)
	{
		long pages = sysconf(_SC_AVPHYS_PAGES);
		long page = sysconf(_SC_PAGESIZE);
		if (pages > 0 && page > 0) value = (long long)pages * page;
	}
	return value;
#endif
}

long long fo_process_memory(void)
{
#if defined(_WIN32)
	PROCESS_MEMORY_COUNTERS counters;
	if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters))) return (long long)counters.WorkingSetSize;
	return -1;
#elif defined(__APPLE__)
	struct mach_task_basic_info info;
	mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
	return (long long)info.resident_size;
#else
	FILE *file = fopen("/proc/self/statm", "r");
	long size = 0;
	long resident = 0;
	if (file == NULL) return -1;
	if (fscanf(file, "%ld %ld", &size, &resident) != 2) resident = -1;
	fclose(file);
	return resident < 0 ? -1 : (long long)resident * sysconf(_SC_PAGESIZE);
#endif
}

int fo_trim_memory(void)
{
#if defined(_WIN32)
	return _heapmin() == 0;
#elif defined(__APPLE__)
	malloc_zone_pressure_relief(NULL, 0);
	return 1;
#elif defined(__ANDROID__)
#ifndef M_PURGE
#define M_PURGE -101
#endif
	return mallopt(M_PURGE, 0) == 1;
#elif defined(__GLIBC__)
	return malloc_trim(0);
#else
	return 0;
#endif
}

int fo_thermal_status(void)
{
#if defined(__ANDROID__)
	fo_load_android();
	if (fo_thermal_acquire == NULL || fo_thermal_get == NULL) return FO_THERMAL_UNKNOWN;
	if (fo_thermal == NULL) fo_thermal = fo_thermal_acquire();
	if (fo_thermal == NULL) return FO_THERMAL_UNKNOWN;
	return fo_thermal_get(fo_thermal);
#else
	return FO_THERMAL_UNKNOWN;
#endif
}

int fo_hint_open(long long target_ns)
{
#if defined(__ANDROID__)
	int tid;
	APerformanceHintManager *manager;
	fo_load_android();
	if (fo_session != NULL) return 1;
	if (!(fo_feature_mask & FO_FEATURE_HINTS) || target_ns <= 0) return 0;
	manager = fo_hint_manager();
	if (manager == NULL) return 0;
	tid = (int)fo_tid();
	fo_session = fo_hint_create(manager, &tid, 1, target_ns);
	return fo_session != NULL;
#else
	(void)target_ns;
	return 0;
#endif
}

void fo_hint_target(long long target_ns)
{
#if defined(__ANDROID__)
	if (fo_session != NULL && fo_hint_update != NULL && target_ns > 0) fo_hint_update(fo_session, target_ns);
#else
	(void)target_ns;
#endif
}

void fo_hint_report(long long actual_ns)
{
#if defined(__ANDROID__)
	if (fo_session != NULL && actual_ns > 0) fo_hint_report_actual(fo_session, actual_ns);
#else
	(void)actual_ns;
#endif
}

void fo_hint_close(void)
{
#if defined(__ANDROID__)
	if (fo_session != NULL && fo_hint_close_session != NULL) fo_hint_close_session(fo_session);
	fo_session = NULL;
#endif
}

int fo_hint_active(void)
{
#if defined(__ANDROID__)
	return fo_session != NULL;
#else
	return 0;
#endif
}
