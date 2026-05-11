#include "cjmp.h"
#include <android/log.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fstream>
#include <filesystem>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/system_properties.h>
#include <unistd.h>
#include <map>
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
std::mutex g_tdBridgeMutex;
long long g_nextTdHandle = 1;

struct TdJsonSymbols {
  void *libraryHandle = nullptr;
  void *(*create)() = nullptr;
  void (*send)(void *, const char *) = nullptr;
  const char *(*receive)(void *, double) = nullptr;
  const char *(*execute)(void *, const char *) = nullptr;
  void (*destroy)(void *) = nullptr;
};

struct TdBridgeClient {
  void *client = nullptr;
};

TdJsonSymbols g_tdJsonSymbols;
std::map<long long, TdBridgeClient> g_tdBridgeClients;

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

std::string BuildTelegramRuntimeConfigPath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegramTdRuntimeConfig.json";
}

std::string BuildTelegramSessionKeyPath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegramTdSessionKey.txt";
}

std::string BuildTelegramTdDbDirPath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegram_tdlib_db";
}

std::string BuildTelegramTdFilesDirPath() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  if (g_demoSessionStorageRoot.empty()) {
    return "";
  }
  return g_demoSessionStorageRoot + "/telegram_tdlib_files";
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

bool ContainsSensitiveTdlibField(const std::string &value) {
  return value.find("\"phone_number\"") != std::string::npos ||
         value.find("\"api_hash\"") != std::string::npos ||
         value.find("\"code\"") != std::string::npos ||
         value.find("\"password\"") != std::string::npos ||
         value.find("\"encryption_key\"") != std::string::npos;
}

std::string SummarizeTdlibPayloadForLog(const char *json) {
  if (json == nullptr) {
    return "null";
  }
  std::string value(json);
  if (ContainsSensitiveTdlibField(value)) {
    return "<redacted sensitive TDLib request>";
  }
  return SummarizeJson(json);
}

std::string ReadTextFile(const std::string &path) {
  if (path.empty()) {
    return "";
  }
  std::ifstream input(path, std::ios::binary);
  if (!input.is_open()) {
    return "";
  }
  return std::string((std::istreambuf_iterator<char>(input)),
                     std::istreambuf_iterator<char>());
}

bool WriteTextFile(const std::string &path, const char *value) {
  if (path.empty()) {
    return false;
  }
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    return false;
  }
  output << (value == nullptr ? "" : value);
  output.close();
  return output.good();
}

void ClearTextFile(const std::string &path) {
  if (path.empty()) {
    return;
  }
  if (std::remove(path.c_str()) != 0 && errno != ENOENT) {
    LOGE("failed to clear file: %s", path.c_str());
  }
}

bool ClearDirectoryRecursively(const std::string &path) {
  if (path.empty()) {
    return false;
  }
  std::error_code error;
  std::filesystem::remove_all(path, error);
  if (error) {
    LOGE("failed to clear directory %s: %s", path.c_str(), error.message().c_str());
    return false;
  }
  return true;
}

bool EnsureTdJsonSymbolsLoaded() {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  if (g_tdJsonSymbols.libraryHandle != nullptr) {
    return g_tdJsonSymbols.create != nullptr && g_tdJsonSymbols.send != nullptr &&
           g_tdJsonSymbols.receive != nullptr && g_tdJsonSymbols.destroy != nullptr;
  }
  void *handle = dlopen("libtdjson.so", RTLD_NOW | RTLD_LOCAL);
  if (handle == nullptr) {
    LOGE("failed to dlopen libtdjson.so: %s", dlerror());
    return false;
  }
  g_tdJsonSymbols.libraryHandle = handle;
  g_tdJsonSymbols.create = reinterpret_cast<void *(*)()>(dlsym(handle, "td_json_client_create"));
  g_tdJsonSymbols.send = reinterpret_cast<void (*)(void *, const char *)>(dlsym(handle, "td_json_client_send"));
  g_tdJsonSymbols.receive = reinterpret_cast<const char *(*)(void *, double)>(dlsym(handle, "td_json_client_receive"));
  g_tdJsonSymbols.execute = reinterpret_cast<const char *(*)(void *, const char *)>(dlsym(handle, "td_json_client_execute"));
  g_tdJsonSymbols.destroy = reinterpret_cast<void (*)(void *)>(dlsym(handle, "td_json_client_destroy"));
  if (g_tdJsonSymbols.create == nullptr || g_tdJsonSymbols.send == nullptr ||
      g_tdJsonSymbols.receive == nullptr || g_tdJsonSymbols.destroy == nullptr) {
    LOGE("failed to load tdjson symbols");
    dlclose(handle);
    g_tdJsonSymbols = TdJsonSymbols();
    return false;
  }
  return true;
}

TdBridgeClient *FindTdBridgeClient(long long handle) {
  auto it = g_tdBridgeClients.find(handle);
  if (it == g_tdBridgeClients.end()) {
    return nullptr;
  }
  return &it->second;
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

long long FfiTdBridgeCreateClient() {
  if (!EnsureTdJsonSymbolsLoaded()) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  void *client = g_tdJsonSymbols.create();
  if (client == nullptr) {
    return 0;
  }
  long long handle = g_nextTdHandle++;
  g_tdBridgeClients[handle] = TdBridgeClient{client};
  return handle;
}

long long FfiTdBridgeSend(long long handle, const char *requestJson) {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  LOGE("FfiTdBridgeSend: ENTER, handle=%lld, request=%s", handle, SummarizeTdlibPayloadForLog(requestJson).c_str());
  TdBridgeClient *client = FindTdBridgeClient(handle);
  if (client == nullptr || client->client == nullptr || requestJson == nullptr) {
    LOGE("FfiTdBridgeSend: validation failed, client=%p, requestJson=%p", client, requestJson);
    return 0;
  }
  LOGE("FfiTdBridgeSend: calling td_json_client_send");
  g_tdJsonSymbols.send(client->client, requestJson);
  LOGE("FfiTdBridgeSend: td_json_client_send completed, returning success");
  return 1;
}

const char *FfiTdBridgePoll(long long handle, long long timeoutMs) {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  LOGE("FfiTdBridgePoll: ENTER, handle=%lld, timeoutMs=%lld", handle, timeoutMs);
  TdBridgeClient *client = FindTdBridgeClient(handle);
  if (client == nullptr || client->client == nullptr) {
    LOGE("FfiTdBridgePoll: client not found or null, returning empty");
    return CopyNativeStringResult("");
  }
  double timeoutSeconds = timeoutMs <= 0 ? 0.0 : static_cast<double>(timeoutMs) / 1000.0;
  LOGE("FfiTdBridgePoll: calling td_json_client_receive with timeout=%.3f seconds", timeoutSeconds);
  const char *response = g_tdJsonSymbols.receive(client->client, timeoutSeconds);
  if (response == nullptr) {
    LOGE("FfiTdBridgePoll: td_json_client_receive returned NULL");
    return CopyNativeStringResult("");
  }
  LOGE("FfiTdBridgePoll: td_json_client_receive returned: %s", SummarizeTdlibPayloadForLog(response).c_str());
  return CopyNativeStringResult(response);
}

long long FfiTdBridgeDestroy(long long handle) {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  auto it = g_tdBridgeClients.find(handle);
  if (it == g_tdBridgeClients.end()) {
    return 0;
  }
  if (it->second.client != nullptr) {
    g_tdJsonSymbols.destroy(it->second.client);
  }
  g_tdBridgeClients.erase(it);
  return 1;
}

long long FfiTdBridgeSetLogVerbosity(long long level) {
  if (!EnsureTdJsonSymbolsLoaded()) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  if (g_tdJsonSymbols.execute == nullptr) {
    return 0;
  }
  std::string request =
      std::string("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":") +
      std::to_string(level) + "}";
  g_tdJsonSymbols.execute(nullptr, request.c_str());
  return 1;
}

long long FfiClearTelegramTdLocalData() {
  bool dbCleared = ClearDirectoryRecursively(BuildTelegramTdDbDirPath());
  bool filesCleared = ClearDirectoryRecursively(BuildTelegramTdFilesDirPath());
  return (dbCleared && filesCleared) ? 1 : 0;
}

long long FfiIsAndroidEmulator() {
  char value[PROP_VALUE_MAX] = {0};
  int length = __system_property_get("ro.kernel.qemu", value);
  return length > 0 && std::strcmp(value, "1") == 0 ? 1 : 0;
}

long long FfiCanReachAndroidLoopbackPort(long long port) {
  if (port <= 0 || port > 65535) {
    return 0;
  }

  int socketFd = socket(AF_INET, SOCK_STREAM, 0);
  if (socketFd < 0) {
    return 0;
  }

  timeval timeout;
  timeout.tv_sec = 1;
  timeout.tv_usec = 0;
  setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
  setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<uint16_t>(port));
  inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);

  int result = connect(socketFd, reinterpret_cast<sockaddr *>(&address), sizeof(address));
  close(socketFd);
  return result == 0 ? 1 : 0;
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

long long FfiSaveTelegramRuntimeConfig(const char *configJson) {
  return WriteTextFile(BuildTelegramRuntimeConfigPath(), configJson) ? 1 : 0;
}

const char *FfiLoadTelegramRuntimeConfig() {
  return CopyNativeStringResult(ReadTextFile(BuildTelegramRuntimeConfigPath()));
}

void FfiClearTelegramRuntimeConfig() {
  ClearTextFile(BuildTelegramRuntimeConfigPath());
}

long long FfiSaveTelegramSessionKey(const char *sessionKey) {
  return WriteTextFile(BuildTelegramSessionKeyPath(), sessionKey) ? 1 : 0;
}

const char *FfiLoadTelegramSessionKey() {
  return CopyNativeStringResult(ReadTextFile(BuildTelegramSessionKeyPath()));
}

void FfiClearTelegramSessionKey() {
  ClearTextFile(BuildTelegramSessionKeyPath());
}

void FfiFreeString(const char *str) {
  free((void *)str);
}

const char *FfiGetApplicationFilesDir() {
  std::lock_guard<std::mutex> lock(g_demoSessionStorageMutex);
  return CopyNativeStringResult(g_demoSessionStorageRoot);
}
