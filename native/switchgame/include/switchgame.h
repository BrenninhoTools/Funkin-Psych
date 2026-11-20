#pragma once

namespace switchgame
{
	const char* version();
	const char* platform();
	const char* lastError();
	const char* launchArguments();

	bool pathExists(const char* path);
	bool packageInstalled(const char* package);
	bool urlAvailable(const char* url);

	bool launchExecutable(const char* path, const char* arguments, const char* workingDirectory);
	bool launchPackage(const char* package, const char* arguments);
	bool launchUrl(const char* url);
}
