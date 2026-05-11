# ifndef CJMP_FFI_H
# define CJMP_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

const char* FfiLogicTest(void);
void FfiFreeString(const char* str);
const char* FfiRunTdjsonPhase0Probe(void);
const char* FfiGetApplicationFilesDir(void);
long long FfiClearTelegramTdLocalData(void);
long long FfiTdBridgeCreateClient(void);
long long FfiTdBridgeSend(long long handle, const char* requestJson);
const char* FfiTdBridgePoll(long long handle, long long timeoutMs);
long long FfiTdBridgeDestroy(long long handle);
long long FfiTdBridgeSetLogVerbosity(long long level);
long long FfiSaveDemoSessionPhone(const char* phoneNumber);
const char* FfiLoadDemoSessionPhone(void);
void FfiClearDemoSessionPhone(void);
long long FfiSaveTelegramRuntimeConfig(const char* configJson);
const char* FfiLoadTelegramRuntimeConfig(void);
void FfiClearTelegramRuntimeConfig(void);
long long FfiSaveTelegramSessionKey(const char* sessionKey);
const char* FfiLoadTelegramSessionKey(void);
void FfiClearTelegramSessionKey(void);

#ifdef __cplusplus
}
#endif

#endif
