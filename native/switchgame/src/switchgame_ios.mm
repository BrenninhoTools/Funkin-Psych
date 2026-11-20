#include "switchgame.cpp"

#import <UIKit/UIKit.h>

namespace switchgame
{
	bool appleOpenUrl(const char* url)
	{
		NSURL* target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
		if (target == nil) return false;
		UIApplication* application = [UIApplication sharedApplication];
		if (![application canOpenURL:target]) return false;
		dispatch_async(dispatch_get_main_queue(), ^{
			[application openURL:target options:@{} completionHandler:nil];
		});
		return true;
	}

	bool appleCanOpenUrl(const char* url)
	{
		NSURL* target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
		return target != nil && [[UIApplication sharedApplication] canOpenURL:target];
	}
}
