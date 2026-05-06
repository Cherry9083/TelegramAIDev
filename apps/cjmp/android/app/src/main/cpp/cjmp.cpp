#include "cjmp.h"
#include <android/log.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fstream>
#include <iterator>
#include <mutex>
#include <string>
#include <vector>

#define LOGTAG "CJMP_JNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOGTAG, __VA_ARGS__)

namespace {

JavaVM *g_javaVm = nullptr;
jclass g_cjmpClass = nullptr;
std::mutex g_demoSessionStorageMutex;
std::string g_demoSessionStorageRoot;

std::string BuildDemoSessionStoragePath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegramCommercialDemoSessionPhone.txt";
}

std::string BuildSmokeStatusPath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegram_ui_smoke_status.txt";
}

const char *CopyNativeStringResult(const std::string &value) {
  return strdup(value.c_str());
}

std::string BuildPhase0Result(bool ok, const std::string &detail) {
  return std::string(ok ? "phase0_ok:" : "phase0_fail:") + detail;
}

std::string SummarizeJson(const char *json) {
  if (json == nullptr) {
    return "null";
  }
  std::string value(json);
  constexpr size_t kMaxLength = 220;
  if (value.size() > kMaxLength) {
    value.resize(kMaxLength);
    value += "...";
  }
  return value;
}

std::string ProbeTdjsonViaDlopen(const char *libraryPath) {
  void *handle = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL);
  if (handle == nullptr) {
    return BuildPhase0Result(false, std::string("dlopen failed: ") + dlerror());
  }

  using TdJsonClientCreateFn = void *(*)();
  using TdJsonClientSendFn = void (*)(void *, const char *);
  using TdJsonClientReceiveFn = const char *(*)(void *, double);
  using TdJsonClientExecuteFn = const char *(*)(void *, const char *);
  using TdJsonClientDestroyFn = void (*)(void *);

  auto create = reinterpret_cast<TdJsonClientCreateFn>(dlsym(handle, "td_json_client_create"));
  auto send = reinterpret_cast<TdJsonClientSendFn>(dlsym(handle, "td_json_client_send"));
  auto receive = reinterpret_cast<TdJsonClientReceiveFn>(dlsym(handle, "td_json_client_receive"));
  auto execute = reinterpret_cast<TdJsonClientExecuteFn>(dlsym(handle, "td_json_client_execute"));
  auto destroy = reinterpret_cast<TdJsonClientDestroyFn>(dlsym(handle, "td_json_client_destroy"));
  if (create == nullptr || send == nullptr || receive == nullptr || destroy == nullptr) {
    dlclose(handle);
    return BuildPhase0Result(false, "dlsym failed for one or more tdjson symbols");
  }

  if (execute != nullptr) {
    execute(nullptr, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
  }

  void *client = create();
  if (client == nullptr) {
    dlclose(handle);
    return BuildPhase0Result(false, "td_json_client_create returned null");
  }

  constexpr const char *kProbeRequest =
      "{\"@type\":\"getTextEntities\",\"text\":\"phase0 probe\",\"@extra\":\"phase0-text-entities\"}";
  send(client, kProbeRequest);

  std::string lastResult = "receive timeout";
  bool matched = false;
  for (int attempt = 0; attempt < 40; ++attempt) {
    const char *response = receive(client, 0.25);
    if (response == nullptr) {
      continue;
    }
    lastResult = SummarizeJson(response);
    if (lastResult.find("\"@extra\":\"phase0-text-entities\"") != std::string::npos &&
        lastResult.find("\"@type\":\"textEntities\"") != std::string::npos) {
      matched = true;
      break;
    }
  }

  destroy(client);
  dlclose(handle);
  return matched ? BuildPhase0Result(true, lastResult) : BuildPhase0Result(false, lastResult);
}

bool GetAttachedEnv(JNIEnv **env) {
  if (g_javaVm == nullptr || env == nullptr) {
    return false;
  }
  return g_javaVm->GetEnv(reinterpret_cast<void **>(env), JNI_VERSION_1_6) == JNI_OK;
}

void ClearJavaException(JNIEnv *env) {
  if (env != nullptr && env->ExceptionCheck()) {
    env->ExceptionDescribe();
    env->ExceptionClear();
  }
}

void WriteSmokeStatusFile(const char *status) {
  std::string storagePath = BuildSmokeStatusPath();
  if (storagePath.empty()) {
    LOGE("smoke status storage root is unavailable");
    return;
  }
  std::ofstream output(storagePath, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    LOGE("failed to open smoke status storage: %s", storagePath.c_str());
    return;
  }
  output << (status == nullptr ? "" : status);
  output.close();
}

}  // namespace

jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  g_javaVm = vm;
  JNIEnv *env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  jclass localClass = env->FindClass("com/example/cjmp/cjmp");
  if (localClass == nullptr) {
    ClearJavaException(env);
    return JNI_ERR;
  }
  g_cjmpClass = reinterpret_cast<jclass>(env->NewGlobalRef(localClass));
  env->DeleteLocalRef(localClass);
  if (g_cjmpClass == nullptr) {
    ClearJavaException(env);
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_cjmp_cjmp_initDemoSessionStorageRoot(JNIEnv *env, jclass clazz,
                                                      jstring storageRoot) {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  g_demoSessionStorageRoot.clear();
  if (storageRoot == nullptr) {
    return;
  }
  const char *chars = env->GetStringUTFChars(storageRoot, nullptr);
  if (chars == nullptr) {
    return;
  }
  g_demoSessionStorageRoot = chars;
  env->ReleaseStringUTFChars(storageRoot, chars);
}

const char *FfiLogicTest() {
  return strdup("String returned from logicTest func in native code.");
}

const char *FfiRunTdjsonPhase0Probe() {
  return CopyNativeStringResult(ProbeTdjsonViaDlopen("libtdjson.so"));
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_cjmp_cjmp_runSmokeSuiteFromNative(JNIEnv *env, jclass clazz) {
  void *handle = dlopen("libohos_app_cangjie_entry.so", RTLD_NOW | RTLD_NOLOAD);
  if (handle == nullptr) {
    handle = dlopen("libohos_app_cangjie_entry.so", RTLD_NOW);
  }
  if (handle == nullptr) {
    LOGE("failed to open libohos_app_cangjie_entry.so: %s", dlerror());
    WriteSmokeStatusFile("crashed");
    return 0;
  }
  using RunSmokeSuiteFn = long long (*)();
  auto runner = reinterpret_cast<RunSmokeSuiteFn>(dlsym(handle, "RunSmokeSuiteFromAttachedThread"));
  if (runner == nullptr) {
    LOGE("failed to locate RunSmokeSuiteFromAttachedThread: %s", dlerror());
    WriteSmokeStatusFile("crashed");
    return 0;
  }
  jlong result = runner();
  WriteSmokeStatusFile(result == 1 ? "passed" : "failed");
  return result;
}

long long FfiStartSmokeSuiteRunner() {
  JNIEnv *env = nullptr;
  if (!GetAttachedEnv(&env) || g_cjmpClass == nullptr) {
    LOGE("failed to resolve attached JNI env for smoke runner");
    return 0;
  }
  jmethodID method = env->GetStaticMethodID(g_cjmpClass, "startSmokeSuiteRunner", "()J");
  if (method == nullptr) {
    ClearJavaException(env);
    return 0;
  }
  jlong started = env->CallStaticLongMethod(g_cjmpClass, method);
  ClearJavaException(env);
  if (started == 1) {
    WriteSmokeStatusFile("running");
  }
  return started;
}

long long FfiSaveDemoSessionPhone(const char *phoneNumber) {
  std::string storagePath = BuildDemoSessionStoragePath();
  if (storagePath.empty()) {
    LOGE("demo session storage root is unavailable");
    return 0;
  }
  std::ofstream output(storagePath, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    LOGE("failed to open demo session storage: %s", storagePath.c_str());
    return 0;
  }
  output << (phoneNumber == nullptr ? "" : phoneNumber);
  output.close();
  return output.good() ? 1 : 0;
}

const char *FfiLoadDemoSessionPhone() {
  std::string storagePath = BuildDemoSessionStoragePath();
  if (storagePath.empty()) {
    return strdup("");
  }
  std::ifstream input(storagePath, std::ios::binary);
  if (!input.is_open()) {
    return strdup("");
  }
  std::string value((std::istreambuf_iterator<char>(input)),
                    std::istreambuf_iterator<char>());
  return CopyNativeStringResult(value);
}

void FfiClearDemoSessionPhone() {
  std::string storagePath = BuildDemoSessionStoragePath();
  if (storagePath.empty()) {
    return;
  }
  if (std::remove(storagePath.c_str()) != 0 && errno != ENOENT) {
    LOGE("failed to clear demo session storage: %s", storagePath.c_str());
  }
}

void FfiFreeString(const char *str) {
  free((void *)str);
}
