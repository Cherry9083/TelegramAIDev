#import "cjmp.h"

__attribute__((visibility("default")))
@implementation cjmp

static NSString *const kDemoSessionPhoneKey = @"telegramCommercialDemoSessionPhone";
static NSString *const kTelegramRuntimeConfigKey = @"telegramTdRuntimeConfig";
static NSString *const kTelegramSessionKey = @"telegramTdSessionKey";

+ (NSString *)logicTest {
    return @"String returned from logicTest func in Objective-C class.";
}

+ (BOOL)saveDemoSessionPhone:(NSString *)phoneNumber {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:phoneNumber forKey:kDemoSessionPhoneKey];
    [defaults synchronize];
    return YES;
}

+ (NSString *)loadDemoSessionPhone {
    NSString *phoneNumber = [[NSUserDefaults standardUserDefaults] stringForKey:kDemoSessionPhoneKey];
    return phoneNumber ?: @"";
}

+ (void)clearDemoSessionPhone {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kDemoSessionPhoneKey];
    [defaults synchronize];
}

+ (BOOL)saveTelegramRuntimeConfig:(NSString *)configJson {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(configJson ?: @"") forKey:kTelegramRuntimeConfigKey];
    [defaults synchronize];
    return YES;
}

+ (NSString *)loadTelegramRuntimeConfig {
    NSString *configJson = [[NSUserDefaults standardUserDefaults] stringForKey:kTelegramRuntimeConfigKey];
    return configJson ?: @"";
}

+ (void)clearTelegramRuntimeConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kTelegramRuntimeConfigKey];
    [defaults synchronize];
}

+ (BOOL)saveTelegramSessionKey:(NSString *)sessionKey {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(sessionKey ?: @"") forKey:kTelegramSessionKey];
    [defaults synchronize];
    return YES;
}

+ (NSString *)loadTelegramSessionKey {
    NSString *sessionKey = [[NSUserDefaults standardUserDefaults] stringForKey:kTelegramSessionKey];
    return sessionKey ?: @"";
}

+ (void)clearTelegramSessionKey {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kTelegramSessionKey];
    [defaults synchronize];
}

@end
