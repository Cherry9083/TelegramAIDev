# ifndef CJMP_H
# define CJMP_H

#include <jni.h>

extern "C" {
const char *FfiLogicTest(void);
long long FfiStartSmokeSuiteRunner(void);
const char *FfiRunTdjsonPhase0Probe(void);
long long FfiTdBridgeCreateClient(void);
long long FfiTdBridgeSend(long long handle, const char *requestJson);
const char *FfiTdBridgePoll(long long handle, long long timeoutMs);
long long FfiTdBridgeDestroy(long long handle);
long long FfiTdBridgeSetLogVerbosity(long long level);
long long FfiClearTelegramTdLocalData(void);
long long FfiIsAndroidEmulator(void);
long long FfiCanReachAndroidLoopbackPort(long long port);
long long FfiSaveDemoSessionPhone(const char *phoneNumber);
const char *FfiLoadDemoSessionPhone(void);
void FfiClearDemoSessionPhone(void);
long long FfiSaveTelegramRuntimeConfig(const char *configJson);
const char *FfiLoadTelegramRuntimeConfig(void);
void FfiClearTelegramRuntimeConfig(void);
long long FfiSaveTelegramSessionKey(const char *sessionKey);
const char *FfiLoadTelegramSessionKey(void);
void FfiClearTelegramSessionKey(void);
const char *FfiGetApplicationFilesDir(void);
void FfiFreeString(const char *str);
}

# endif
