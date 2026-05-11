#include "cjmp_ffi.h"

#import "cjmp.h"
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#include <stdio.h>

@interface TdJsonClientBox : NSObject
@property (nonatomic, assign) int clientId;
@end

@implementation TdJsonClientBox
@end

static NSString *BuildPhase0Result(BOOL ok, NSString *detail) {
    return [NSString stringWithFormat:@"%@%@", ok ? @"phase0_ok:" : @"phase0_fail:", detail ?: @"missing-detail"];
}

static NSString *SummarizeJson(const char *json) {
    if (json == NULL) {
        return @"null";
    }
    NSString *value = [NSString stringWithUTF8String:json];
    if (value == nil) {
        return @"non-utf8-response";
    }
    if (value.length > 220) {
        return [[value substringToIndex:220] stringByAppendingString:@"..."];
    }
    return value;
}

static void *gTdJsonLibraryHandle = NULL;
static int (*gTdCreateClientId)(void) = NULL;
static void (*gTdSend)(int, const char *) = NULL;
static const char *(*gTdReceive)(double) = NULL;
static const char *(*gTdExecute)(const char *) = NULL;
static NSMutableDictionary<NSNumber *, TdJsonClientBox *> *gTdJsonClients = nil;
static long long gNextTdJsonHandle = 1;

static NSObject *TdJsonBridgeLock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

static BOOL EnsureTdJsonLibraryLoaded(void) {
    if (gTdJsonLibraryHandle != NULL) {
        return gTdCreateClientId != NULL && gTdSend != NULL && gTdReceive != NULL;
    }
    NSString *frameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
    NSString *libraryPath = [frameworksPath stringByAppendingPathComponent:@"libtdjson.dylib"];
    void *handle = dlopen(libraryPath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        fprintf(stderr, "EnsureTdJsonLibraryLoaded: dlopen failed path=%s error=%s\n", libraryPath.UTF8String, dlerror());
        return NO;
    }
    gTdJsonLibraryHandle = handle;
    gTdCreateClientId = (int (*)(void))dlsym(handle, "td_create_client_id");
    gTdSend = (void (*)(int, const char *))dlsym(handle, "td_send");
    gTdReceive = (const char *(*)(double))dlsym(handle, "td_receive");
    gTdExecute = (const char *(*)(const char *))dlsym(handle, "td_execute");
    if (gTdCreateClientId == NULL || gTdSend == NULL || gTdReceive == NULL) {
        fprintf(stderr, "EnsureTdJsonLibraryLoaded: required tdjson symbols missing create=%p send=%p receive=%p execute=%p\n", gTdCreateClientId, gTdSend, gTdReceive, gTdExecute);
        dlclose(handle);
        gTdJsonLibraryHandle = NULL;
        gTdCreateClientId = NULL;
        gTdSend = NULL;
        gTdReceive = NULL;
        gTdExecute = NULL;
        return NO;
    }
    if (gTdJsonClients == nil) {
        gTdJsonClients = [[NSMutableDictionary alloc] init];
    }
    return YES;
}

static TdJsonClientBox *FindTdJsonClient(long long handle) {
    if (gTdJsonClients == nil) {
        return nil;
    }
    return gTdJsonClients[@(handle)];
}

static NSString *ProbeTdjsonFromBundle(void) {
    @synchronized (TdJsonBridgeLock()) {
        if (!EnsureTdJsonLibraryLoaded()) {
            return BuildPhase0Result(NO, @"failed to load td_create_client_id tdjson symbols");
        }

        if (gTdExecute != NULL) {
            gTdExecute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
        }

        int clientId = gTdCreateClientId();
        if (clientId == 0) {
            return BuildPhase0Result(NO, @"td_create_client_id returned zero");
        }

        gTdSend(clientId, "{\"@type\":\"getTextEntities\",\"text\":\"phase0 probe\",\"@extra\":\"phase0-text-entities\"}");

        NSString *lastResult = @"receive timeout";
        BOOL matched = NO;
        for (NSInteger attempt = 0; attempt < 40; attempt++) {
            const char *response = gTdReceive(0.25);
            if (response == NULL) {
                continue;
            }
            lastResult = SummarizeJson(response);
            if ([lastResult containsString:@"\"@extra\":\"phase0-text-entities\""] &&
                [lastResult containsString:@"\"@type\":\"textEntities\""]) {
                matched = YES;
                break;
            }
        }

        gTdSend(clientId, "{\"@type\":\"close\",\"@extra\":\"phase0-close\"}");
        return BuildPhase0Result(matched, lastResult);
    }
}

const char* FfiLogicTest(void) {
    @autoreleasepool {
        NSString *result = [cjmp logicTest];
        return strdup([result UTF8String]);
    }
}

void FfiFreeString(const char* str) {
    free((void*)str);
}

const char* FfiRunTdjsonPhase0Probe(void) {
    @autoreleasepool {
        NSString *result = ProbeTdjsonFromBundle();
        return strdup([result UTF8String]);
    }
}

const char* FfiGetApplicationFilesDir(void) {
    @autoreleasepool {
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        NSURL *baseURL = urls.firstObject;
        if (baseURL == nil) {
            baseURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        }
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.example.cjmp";
        NSURL *appURL = [baseURL URLByAppendingPathComponent:bundleId isDirectory:YES];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:appURL withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            return strdup([NSTemporaryDirectory() UTF8String]);
        }
        return strdup([appURL.path UTF8String]);
    }
}

long long FfiClearTelegramTdLocalData(void) {
    @autoreleasepool {
        const char *filesDirCString = FfiGetApplicationFilesDir();
        NSString *filesDir = filesDirCString == NULL ? @"" : [NSString stringWithUTF8String:filesDirCString];
        free((void *)filesDirCString);
        if (filesDir.length == 0) {
            return 0;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSString *> *tdlibDirectories = @[
            [filesDir stringByAppendingPathComponent:@"telegram_tdlib_db"],
            [filesDir stringByAppendingPathComponent:@"telegram_tdlib_files"]
        ];
        for (NSString *path in tdlibDirectories) {
            NSError *error = nil;
            if (![fileManager removeItemAtPath:path error:&error] && error != nil) {
                if (error.domain != NSCocoaErrorDomain || error.code != NSFileNoSuchFileError) {
                    fprintf(stderr, "FfiClearTelegramTdLocalData: failed to remove %s: %s\n", path.UTF8String, error.localizedDescription.UTF8String);
                    return 0;
                }
            }
        }
        return 1;
    }
}

long long FfiTdBridgeCreateClient(void) {
    @autoreleasepool {
        @synchronized (TdJsonBridgeLock()) {
            fprintf(stderr, "FfiTdBridgeCreateClient: ENTER\n");
            if (!EnsureTdJsonLibraryLoaded()) {
                fprintf(stderr, "FfiTdBridgeCreateClient: tdjson load failed\n");
                return 0;
            }
            fprintf(stderr, "FfiTdBridgeCreateClient: calling td_create_client_id\n");
            int clientId = gTdCreateClientId();
            fprintf(stderr, "FfiTdBridgeCreateClient: td_create_client_id returned %d\n", clientId);
            if (clientId == 0) {
                return 0;
            }
            TdJsonClientBox *box = [[TdJsonClientBox alloc] init];
            box.clientId = clientId;
            long long handle = gNextTdJsonHandle++;
            gTdJsonClients[@(handle)] = box;
#if !__has_feature(objc_arc)
            [box release];
#endif
            fprintf(stderr, "FfiTdBridgeCreateClient: EXIT handle=%lld clientId=%d\n", handle, clientId);
            return handle;
        }
    }
}

long long FfiTdBridgeSend(long long handle, const char* requestJson) {
    @autoreleasepool {
        @synchronized (TdJsonBridgeLock()) {
            TdJsonClientBox *box = FindTdJsonClient(handle);
            if (box == nil || box.clientId == 0 || requestJson == NULL) {
                return 0;
            }
            gTdSend(box.clientId, requestJson);
            return 1;
        }
    }
}

const char* FfiTdBridgePoll(long long handle, long long timeoutMs) {
    @autoreleasepool {
        @synchronized (TdJsonBridgeLock()) {
            TdJsonClientBox *box = FindTdJsonClient(handle);
            if (box == nil || box.clientId == 0) {
                return strdup("");
            }
            double timeoutSeconds = timeoutMs <= 0 ? 0.0 : ((double)timeoutMs / 1000.0);
            const char *response = gTdReceive(timeoutSeconds);
            if (response == NULL) {
                return strdup("");
            }
            return strdup(response);
        }
    }
}

long long FfiTdBridgeDestroy(long long handle) {
    @autoreleasepool {
        @synchronized (TdJsonBridgeLock()) {
            TdJsonClientBox *box = FindTdJsonClient(handle);
            if (box == nil) {
                return 0;
            }
            if (box.clientId != 0) {
                gTdSend(box.clientId, "{\"@type\":\"close\",\"@extra\":\"destroy-client\"}");
            }
            box.clientId = 0;
            [gTdJsonClients removeObjectForKey:@(handle)];
            return 1;
        }
    }
}

long long FfiTdBridgeSetLogVerbosity(long long level) {
    @autoreleasepool {
        @synchronized (TdJsonBridgeLock()) {
            if (!EnsureTdJsonLibraryLoaded() || gTdExecute == NULL) {
                return 0;
            }
            NSString *request = [NSString stringWithFormat:@"{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":%lld}", level];
            gTdExecute(request.UTF8String);
            return 1;
        }
    }
}

long long FfiSaveDemoSessionPhone(const char* phoneNumber) {
    @autoreleasepool {
        NSString *value = phoneNumber == NULL ? @"" : [NSString stringWithUTF8String:phoneNumber];
        return [cjmp saveDemoSessionPhone:value] ? 1 : 0;
    }
}

const char* FfiLoadDemoSessionPhone(void) {
    @autoreleasepool {
        NSString *result = [cjmp loadDemoSessionPhone];
        return strdup([result UTF8String]);
    }
}

void FfiClearDemoSessionPhone(void) {
    @autoreleasepool {
        [cjmp clearDemoSessionPhone];
    }
}

long long FfiSaveTelegramRuntimeConfig(const char* configJson) {
    @autoreleasepool {
        NSString *value = configJson == NULL ? @"" : [NSString stringWithUTF8String:configJson];
        return [cjmp saveTelegramRuntimeConfig:value] ? 1 : 0;
    }
}

const char* FfiLoadTelegramRuntimeConfig(void) {
    @autoreleasepool {
        NSString *result = [cjmp loadTelegramRuntimeConfig];
        return strdup([result UTF8String]);
    }
}

void FfiClearTelegramRuntimeConfig(void) {
    @autoreleasepool {
        [cjmp clearTelegramRuntimeConfig];
    }
}

long long FfiSaveTelegramSessionKey(const char* sessionKey) {
    @autoreleasepool {
        NSString *value = sessionKey == NULL ? @"" : [NSString stringWithUTF8String:sessionKey];
        return [cjmp saveTelegramSessionKey:value] ? 1 : 0;
    }
}

const char* FfiLoadTelegramSessionKey(void) {
    @autoreleasepool {
        NSString *result = [cjmp loadTelegramSessionKey];
        return strdup([result UTF8String]);
    }
}

void FfiClearTelegramSessionKey(void) {
    @autoreleasepool {
        [cjmp clearTelegramSessionKey];
    }
}
