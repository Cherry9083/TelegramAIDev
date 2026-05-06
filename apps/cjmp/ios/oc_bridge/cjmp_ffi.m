#include "cjmp_ffi.h"

#import "cjmp.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>

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

static NSString *ProbeTdjsonFromBundle(void) {
    NSString *frameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
    NSString *libraryPath = [frameworksPath stringByAppendingPathComponent:@"libtdjson.dylib"];
    void *handle = dlopen(libraryPath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        return BuildPhase0Result(NO, [NSString stringWithFormat:@"dlopen failed: %s", dlerror()]);
    }

    typedef void *(*TdJsonClientCreateFn)(void);
    typedef void (*TdJsonClientSendFn)(void *, const char *);
    typedef const char *(*TdJsonClientReceiveFn)(void *, double);
    typedef const char *(*TdJsonClientExecuteFn)(void *, const char *);
    typedef void (*TdJsonClientDestroyFn)(void *);

    TdJsonClientCreateFn create = (TdJsonClientCreateFn)dlsym(handle, "td_json_client_create");
    TdJsonClientSendFn send = (TdJsonClientSendFn)dlsym(handle, "td_json_client_send");
    TdJsonClientReceiveFn receive = (TdJsonClientReceiveFn)dlsym(handle, "td_json_client_receive");
    TdJsonClientExecuteFn execute = (TdJsonClientExecuteFn)dlsym(handle, "td_json_client_execute");
    TdJsonClientDestroyFn destroy = (TdJsonClientDestroyFn)dlsym(handle, "td_json_client_destroy");
    if (create == NULL || send == NULL || receive == NULL || destroy == NULL) {
        dlclose(handle);
        return BuildPhase0Result(NO, @"dlsym failed for one or more tdjson symbols");
    }

    if (execute != NULL) {
        execute(NULL, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
    }

    void *client = create();
    if (client == NULL) {
        dlclose(handle);
        return BuildPhase0Result(NO, @"td_json_client_create returned null");
    }

    send(client, "{\"@type\":\"getTextEntities\",\"text\":\"phase0 probe\",\"@extra\":\"phase0-text-entities\"}");

    NSString *lastResult = @"receive timeout";
    BOOL matched = NO;
    for (NSInteger attempt = 0; attempt < 40; attempt++) {
        const char *response = receive(client, 0.25);
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

    destroy(client);
    dlclose(handle);
    return BuildPhase0Result(matched, lastResult);
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
