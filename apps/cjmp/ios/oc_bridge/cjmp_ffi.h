# ifndef CJMP_FFI_H
# define CJMP_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

const char* FfiLogicTest(void);
void FfiFreeString(const char* str);
const char* FfiRunTdjsonPhase0Probe(void);
long long FfiSaveDemoSessionPhone(const char* phoneNumber);
const char* FfiLoadDemoSessionPhone(void);
void FfiClearDemoSessionPhone(void);

#ifdef __cplusplus
}
#endif

#endif
