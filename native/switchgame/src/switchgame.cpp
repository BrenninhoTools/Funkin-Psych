#include "switchgame.h"

#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#endif

#if defined(__ANDROID__)
#include <jni.h>
#include <dlfcn.h>

extern "C"
{
	__attribute__((weak)) void* SDL_GetAndroidJNIEnv();
	__attribute__((weak)) void* SDL_GetAndroidActivity();
	__attribute__((weak)) void* SDL_AndroidGetJNIEnv();
	__attribute__((weak)) void* SDL_AndroidGetActivity();
}
#endif

namespace
{
	std::string errorText;
	std::string argumentsText;

	void fail(const std::string& message)
	{
		errorText = message;
	}

	std::vector<std::string> splitArguments(const char* arguments)
	{
		std::vector<std::string> list;
		if (arguments == NULL) return list;
		std::string current;
		for (const char* c = arguments; *c; c++)
		{
			if (*c == '\n')
			{
				if (!current.empty()) list.push_back(current);
				current.clear();
			}
			else current += *c;
		}
		if (!current.empty()) list.push_back(current);
		return list;
	}

#if defined(__APPLE__)
	bool endsWith(const std::string& text, const std::string& suffix)
	{
		return text.size() >= suffix.size() && text.compare(text.size() - suffix.size(), suffix.size(), suffix) == 0;
	}
#endif

#if defined(_WIN32)
	std::wstring widen(const std::string& text)
	{
		if (text.empty()) return std::wstring();
		int size = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), (int)text.size(), NULL, 0);
		std::wstring result(size, 0);
		MultiByteToWideChar(CP_UTF8, 0, text.c_str(), (int)text.size(), &result[0], size);
		return result;
	}

	std::wstring quote(const std::wstring& argument)
	{
		if (!argument.empty() && argument.find_first_of(L" \t\"") == std::wstring::npos) return argument;
		std::wstring result = L"\"";
		size_t slashes = 0;
		for (wchar_t c : argument)
		{
			if (c == L'\\') slashes++;
			else if (c == L'"')
			{
				result.append(slashes * 2 + 1, L'\\');
				result += c;
				slashes = 0;
				continue;
			}
			else slashes = 0;
			result += c;
		}
		result.append(slashes * 2, L'\\');
		result += L'"';
		return result;
	}

	std::string windowsError()
	{
		DWORD code = GetLastError();
		char buffer[256] = {0};
		FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, code, 0, buffer, sizeof(buffer) - 1, NULL);
		return std::string(buffer);
	}
#else
	bool spawnDetached(const std::vector<std::string>& command, const char* workingDirectory)
	{
		int pipeFds[2];
		if (pipe(pipeFds) != 0)
		{
			fail("Could not create pipe");
			return false;
		}
		fcntl(pipeFds[1], F_SETFD, FD_CLOEXEC);

		pid_t pid = fork();
		if (pid < 0)
		{
			close(pipeFds[0]);
			close(pipeFds[1]);
			fail("Could not fork process");
			return false;
		}

		if (pid == 0)
		{
			close(pipeFds[0]);
			setsid();
			signal(SIGCHLD, SIG_DFL);
			if (workingDirectory != NULL && workingDirectory[0] != '\0' && chdir(workingDirectory) != 0)
			{
				int code = errno;
				ssize_t written = write(pipeFds[1], &code, sizeof(code));
				(void)written;
				_exit(127);
			}
			std::vector<char*> argv;
			for (size_t i = 0; i < command.size(); i++) argv.push_back(const_cast<char*>(command[i].c_str()));
			argv.push_back(NULL);
			execvp(argv[0], argv.data());
			int code = errno;
			ssize_t written = write(pipeFds[1], &code, sizeof(code));
			(void)written;
			_exit(127);
		}

		close(pipeFds[1]);
		int code = 0;
		ssize_t got = read(pipeFds[0], &code, sizeof(code));
		close(pipeFds[0]);
		if (got > 0)
		{
			fail(std::string("Could not start process: ") + strerror(code));
			return false;
		}
		return true;
	}
#endif

#if defined(__ANDROID__)
	typedef void* (*GetPointer)();

	GetPointer findBridge(const char* const* names)
	{
		static const char* libraries[] = {"libApplicationMain.so", "libmain.so", "liblime.so", "libSDL3.so", "libSDL2.so", NULL};
		for (const char* const* name = names; *name != NULL; name++)
		{
			void* symbol = dlsym(RTLD_DEFAULT, *name);
			if (symbol != NULL) return (GetPointer)symbol;
		}
		for (const char** library = libraries; *library != NULL; library++)
		{
			void* handle = dlopen(*library, RTLD_NOW | RTLD_NOLOAD);
			if (handle == NULL) continue;
			for (const char* const* name = names; *name != NULL; name++)
			{
				void* symbol = dlsym(handle, *name);
				if (symbol != NULL) return (GetPointer)symbol;
			}
		}
		return NULL;
	}

	struct AndroidContext
	{
		JNIEnv* env;
		jobject activity;
	};

	bool androidContext(AndroidContext& context)
	{
		static const char* envNames[] = {"SDL_GetAndroidJNIEnv", "SDL_AndroidGetJNIEnv", NULL};
		static const char* activityNames[] = {"SDL_GetAndroidActivity", "SDL_AndroidGetActivity", NULL};
		GetPointer getEnv = SDL_GetAndroidJNIEnv != NULL ? (GetPointer)SDL_GetAndroidJNIEnv : (SDL_AndroidGetJNIEnv != NULL ? (GetPointer)SDL_AndroidGetJNIEnv : findBridge(envNames));
		GetPointer getActivity = SDL_GetAndroidActivity != NULL ? (GetPointer)SDL_GetAndroidActivity : (SDL_AndroidGetActivity != NULL ? (GetPointer)SDL_AndroidGetActivity : findBridge(activityNames));
		if (getEnv == NULL || getActivity == NULL)
		{
			fail("SDL Android bridge was not found");
			return false;
		}
		context.env = (JNIEnv*)getEnv();
		context.activity = (jobject)getActivity();
		if (context.env == NULL || context.activity == NULL)
		{
			fail("Android activity is not available");
			return false;
		}
		return true;
	}

	bool clearException(JNIEnv* env)
	{
		if (!env->ExceptionCheck()) return false;
		env->ExceptionClear();
		return true;
	}

	jobject launchIntent(JNIEnv* env, jobject activity, const char* package)
	{
		jclass activityClass = env->GetObjectClass(activity);
		jmethodID getPackageManager = env->GetMethodID(activityClass, "getPackageManager", "()Landroid/content/pm/PackageManager;");
		jobject manager = env->CallObjectMethod(activity, getPackageManager);
		env->DeleteLocalRef(activityClass);
		if (clearException(env) || manager == NULL) return NULL;

		jclass managerClass = env->GetObjectClass(manager);
		jmethodID getLaunchIntent = env->GetMethodID(managerClass, "getLaunchIntentForPackage", "(Ljava/lang/String;)Landroid/content/Intent;");
		jstring name = env->NewStringUTF(package);
		jobject intent = env->CallObjectMethod(manager, getLaunchIntent, name);
		env->DeleteLocalRef(name);
		env->DeleteLocalRef(managerClass);
		env->DeleteLocalRef(manager);
		if (clearException(env)) return NULL;
		return intent;
	}

	bool startIntent(JNIEnv* env, jobject activity, jobject intent, const char* arguments)
	{
		jclass intentClass = env->GetObjectClass(intent);
		jmethodID addFlags = env->GetMethodID(intentClass, "addFlags", "(I)Landroid/content/Intent;");
		jobject chained = env->CallObjectMethod(intent, addFlags, (jint)0x10000000);
		if (chained != NULL) env->DeleteLocalRef(chained);
		if (arguments != NULL && arguments[0] != '\0')
		{
			jmethodID putExtra = env->GetMethodID(intentClass, "putExtra", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
			jstring key = env->NewStringUTF("switchgame.arguments");
			jstring value = env->NewStringUTF(arguments);
			jobject result = env->CallObjectMethod(intent, putExtra, key, value);
			if (result != NULL) env->DeleteLocalRef(result);
			env->DeleteLocalRef(key);
			env->DeleteLocalRef(value);
		}
		env->DeleteLocalRef(intentClass);

		jclass activityClass = env->GetObjectClass(activity);
		jmethodID startActivity = env->GetMethodID(activityClass, "startActivity", "(Landroid/content/Intent;)V");
		env->CallVoidMethod(activity, startActivity, intent);
		env->DeleteLocalRef(activityClass);
		if (clearException(env))
		{
			fail("Android refused to start the activity");
			return false;
		}
		return true;
	}

	bool startView(JNIEnv* env, jobject activity, const char* url)
	{
		jclass uriClass = env->FindClass("android/net/Uri");
		jmethodID parse = env->GetStaticMethodID(uriClass, "parse", "(Ljava/lang/String;)Landroid/net/Uri;");
		jstring text = env->NewStringUTF(url);
		jobject uri = env->CallStaticObjectMethod(uriClass, parse, text);
		env->DeleteLocalRef(text);
		env->DeleteLocalRef(uriClass);
		if (clearException(env) || uri == NULL)
		{
			fail("Invalid url");
			return false;
		}
		jclass intentClass = env->FindClass("android/content/Intent");
		jmethodID constructor = env->GetMethodID(intentClass, "<init>", "(Ljava/lang/String;Landroid/net/Uri;)V");
		jstring action = env->NewStringUTF("android.intent.action.VIEW");
		jobject intent = env->NewObject(intentClass, constructor, action, uri);
		env->DeleteLocalRef(action);
		env->DeleteLocalRef(uri);
		env->DeleteLocalRef(intentClass);
		if (clearException(env) || intent == NULL)
		{
			fail("Could not build the intent");
			return false;
		}
		bool started = startIntent(env, activity, intent, NULL);
		env->DeleteLocalRef(intent);
		return started;
	}
#endif
}

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
namespace switchgame
{
	bool appleOpenUrl(const char* url);
	bool appleCanOpenUrl(const char* url);
}
#endif

namespace switchgame
{
	const char* version()
	{
		return "1.0.0";
	}

	const char* platform()
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

	const char* lastError()
	{
		return errorText.c_str();
	}

	const char* launchArguments()
	{
		argumentsText.clear();
#if defined(__ANDROID__)
		AndroidContext context;
		if (!androidContext(context)) return argumentsText.c_str();
		JNIEnv* env = context.env;
		jclass activityClass = env->GetObjectClass(context.activity);
		jmethodID getIntent = env->GetMethodID(activityClass, "getIntent", "()Landroid/content/Intent;");
		jobject intent = env->CallObjectMethod(context.activity, getIntent);
		env->DeleteLocalRef(activityClass);
		if (!clearException(env) && intent != NULL)
		{
			jclass intentClass = env->GetObjectClass(intent);
			jmethodID getExtra = env->GetMethodID(intentClass, "getStringExtra", "(Ljava/lang/String;)Ljava/lang/String;");
			jstring key = env->NewStringUTF("switchgame.arguments");
			jstring value = (jstring)env->CallObjectMethod(intent, getExtra, key);
			env->DeleteLocalRef(key);
			if (!clearException(env) && value != NULL)
			{
				const char* chars = env->GetStringUTFChars(value, NULL);
				if (chars != NULL)
				{
					argumentsText = chars;
					env->ReleaseStringUTFChars(value, chars);
				}
				env->DeleteLocalRef(value);
			}
			env->DeleteLocalRef(intentClass);
			env->DeleteLocalRef(intent);
		}
		env->DeleteLocalRef(context.activity);
#endif
		return argumentsText.c_str();
	}

	bool pathExists(const char* path)
	{
		if (path == NULL || path[0] == '\0') return false;
#if defined(_WIN32)
		DWORD attributes = GetFileAttributesW(widen(path).c_str());
		return attributes != INVALID_FILE_ATTRIBUTES;
#else
		struct stat info;
		return stat(path, &info) == 0;
#endif
	}

	bool packageInstalled(const char* package)
	{
#if defined(__ANDROID__)
		if (package == NULL || package[0] == '\0') return false;
		AndroidContext context;
		if (!androidContext(context)) return false;
		jobject intent = launchIntent(context.env, context.activity, package);
		bool found = intent != NULL;
		if (intent != NULL) context.env->DeleteLocalRef(intent);
		context.env->DeleteLocalRef(context.activity);
		return found;
#else
		(void)package;
		return false;
#endif
	}

	bool urlAvailable(const char* url)
	{
		if (url == NULL || url[0] == '\0') return false;
#if defined(__APPLE__) && TARGET_OS_IPHONE
		return appleCanOpenUrl(url);
#else
		return true;
#endif
	}

	bool launchExecutable(const char* path, const char* arguments, const char* workingDirectory)
	{
		errorText.clear();
		if (!pathExists(path))
		{
			fail(std::string("Engine not found: ") + (path != NULL ? path : ""));
			return false;
		}
		std::vector<std::string> args = splitArguments(arguments);
#if defined(_WIN32)
		std::wstring command = quote(widen(path));
		for (size_t i = 0; i < args.size(); i++) command += L" " + quote(widen(args[i]));
		std::wstring directory = workingDirectory != NULL ? widen(workingDirectory) : std::wstring();
		STARTUPINFOW startup;
		PROCESS_INFORMATION process;
		ZeroMemory(&startup, sizeof(startup));
		ZeroMemory(&process, sizeof(process));
		startup.cb = sizeof(startup);
		std::vector<wchar_t> buffer(command.begin(), command.end());
		buffer.push_back(0);
		BOOL created = CreateProcessW(NULL, buffer.data(), NULL, NULL, FALSE, DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP, NULL, directory.empty() ? NULL : directory.c_str(), &startup, &process);
		if (!created)
		{
			fail("Could not start process: " + windowsError());
			return false;
		}
		CloseHandle(process.hThread);
		CloseHandle(process.hProcess);
		return true;
#elif defined(__APPLE__) && TARGET_OS_IPHONE
		(void)args;
		(void)workingDirectory;
		fail("iOS can only switch engines through url schemes");
		return false;
#else
		std::vector<std::string> command;
		std::string target = path;
#if defined(__APPLE__)
		if (endsWith(target, ".app") || endsWith(target, ".app/"))
		{
			command.push_back("/usr/bin/open");
			command.push_back("-n");
			command.push_back(target);
			if (!args.empty()) command.push_back("--args");
		}
		else command.push_back(target);
#else
		command.push_back(target);
#endif
		for (size_t i = 0; i < args.size(); i++) command.push_back(args[i]);
		return spawnDetached(command, workingDirectory);
#endif
	}

	bool launchPackage(const char* package, const char* arguments)
	{
		errorText.clear();
#if defined(__ANDROID__)
		if (package == NULL || package[0] == '\0')
		{
			fail("Missing package name");
			return false;
		}
		AndroidContext context;
		if (!androidContext(context)) return false;
		jobject intent = launchIntent(context.env, context.activity, package);
		if (intent == NULL)
		{
			context.env->DeleteLocalRef(context.activity);
			fail(std::string("Engine is not installed: ") + package);
			return false;
		}
		bool started = startIntent(context.env, context.activity, intent, arguments);
		context.env->DeleteLocalRef(intent);
		context.env->DeleteLocalRef(context.activity);
		return started;
#else
		(void)package;
		(void)arguments;
		fail("Packages can only be launched on Android");
		return false;
#endif
	}

	bool launchUrl(const char* url)
	{
		errorText.clear();
		if (url == NULL || url[0] == '\0')
		{
			fail("Missing url");
			return false;
		}
#if defined(__ANDROID__)
		AndroidContext context;
		if (!androidContext(context)) return false;
		bool started = startView(context.env, context.activity, url);
		context.env->DeleteLocalRef(context.activity);
		return started;
#elif defined(__APPLE__) && TARGET_OS_IPHONE
		if (!appleOpenUrl(url))
		{
			fail(std::string("No engine handles ") + url);
			return false;
		}
		return true;
#elif defined(_WIN32)
		HINSTANCE result = ShellExecuteW(NULL, L"open", widen(url).c_str(), NULL, NULL, SW_SHOWNORMAL);
		if ((INT_PTR)result <= 32)
		{
			fail("Could not open url");
			return false;
		}
		return true;
#elif defined(__APPLE__)
		std::vector<std::string> command;
		command.push_back("/usr/bin/open");
		command.push_back(url);
		return spawnDetached(command, NULL);
#else
		std::vector<std::string> command;
		command.push_back("xdg-open");
		command.push_back(url);
		return spawnDetached(command, NULL);
#endif
	}
}
