#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#include <hilog/log.h>
#include <network/netmanager/net_connection.h>
#include <network/netmanager/net_connection_type.h>

#define LOG_DOMAIN 0xC04D0
#define LOG_TAG "CJMP_OHOS"
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

namespace {

constexpr const char *kTdJsonLibraryName = "libtdjson.so";
constexpr const char *kAppFilesDir = "/data/storage/el2/base/files";
constexpr const char *kFallbackAppFilesDir = "/data/storage/el1/base/files";
constexpr size_t kLogPayloadMaxLength = 220;

std::mutex g_storageMutex;
std::string g_storageRoot;
std::mutex g_tdBridgeMutex;
long long g_nextTdHandle = 1;

struct TdJsonSymbols {
  void *(*create)() = nullptr;
  void (*send)(void *, const char *) = nullptr;
  const char *(*receive)(void *, double) = nullptr;
  const char *(*execute)(void *, const char *) = nullptr;
  void (*destroy)(void *) = nullptr;
};

struct TdBridgeClient {
  void *client = nullptr;
};

struct OhosHttpProxyConfig {
  std::string host;
  int port = 0;
};

TdJsonSymbols g_tdJsonSymbols;
std::map<long long, TdBridgeClient> g_tdBridgeClients;

extern "C" void *td_json_client_create();
extern "C" void td_json_client_send(void *client, const char *request);
extern "C" const char *td_json_client_receive(void *client, double timeout);
extern "C" const char *td_json_client_execute(void *client, const char *request);
extern "C" void td_json_client_destroy(void *client);

const char *CopyNativeStringResult(const std::string &value) {
  return strdup(value.c_str());
}

std::string BuildPhase0Result(bool ok, const std::string &detail) {
  return std::string(ok ? "phase0_ok:" : "phase0_fail:") + detail;
}

OhosHttpProxyConfig ReadOhosDefaultHttpProxy() {
  NetConn_HttpProxy httpProxy = {};
  int32_t result = OH_NetConn_GetDefaultHttpProxy(&httpProxy);
  if (result != 0) {
    LOGE("OH_NetConn_GetDefaultHttpProxy failed, result=%{public}d", result);
    return OhosHttpProxyConfig();
  }

  std::string host(httpProxy.host);
  int port = static_cast<int>(httpProxy.port);
  if (host.empty() || port <= 0) {
    LOGI("OHOS default HTTP proxy is empty, result=%{public}d, port=%{public}d", result, port);
    return OhosHttpProxyConfig();
  }

  LOGI("OHOS default HTTP proxy detected: %{public}s:%{public}d", host.c_str(), port);
  return OhosHttpProxyConfig{host, port};
}

std::string SummarizeJson(const char *json) {
  if (json == nullptr) {
    return "null";
  }
  std::string value(json);
  if (value.size() > kLogPayloadMaxLength) {
    value.resize(kLogPayloadMaxLength);
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

bool EnsureDirectory(const std::string &path) {
  std::error_code error;
  std::filesystem::create_directories(path, error);
  return !error;
}

std::string ResolveAppFilesDir() {
  std::lock_guard<std::mutex> lock(g_storageMutex);
  if (!g_storageRoot.empty()) {
    return g_storageRoot;
  }
  if (EnsureDirectory(kAppFilesDir)) {
    g_storageRoot = kAppFilesDir;
    return g_storageRoot;
  }
  if (EnsureDirectory(kFallbackAppFilesDir)) {
    g_storageRoot = kFallbackAppFilesDir;
    return g_storageRoot;
  }
  LOGE("failed to resolve writable OHOS files directory");
  return "";
}

std::string BuildStoragePath(const char *fileName) {
  std::string root = ResolveAppFilesDir();
  if (root.empty()) {
    return "";
  }
  return root + "/" + fileName;
}

std::string BuildTelegramTdDbDirPath() {
  std::string root = ResolveAppFilesDir();
  return root.empty() ? "" : root + "/telegram_tdlib_db";
}

std::string BuildTelegramTdFilesDirPath() {
  std::string root = ResolveAppFilesDir();
  return root.empty() ? "" : root + "/telegram_tdlib_files";
}

std::string ReadTextFile(const std::string &path) {
  if (path.empty()) {
    return "";
  }
  std::ifstream input(path, std::ios::binary);
  if (!input.is_open()) {
    return "";
  }
  return std::string((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
}

bool WriteTextFile(const std::string &path, const char *value) {
  if (path.empty()) {
    return false;
  }
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    LOGE("failed to open storage file: %{public}s", path.c_str());
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
    LOGE("failed to clear file: %{public}s", path.c_str());
  }
}

bool ClearDirectoryRecursively(const std::string &path) {
  if (path.empty()) {
    return false;
  }
  std::error_code error;
  std::filesystem::remove_all(path, error);
  if (error) {
    LOGE("failed to clear directory %{public}s: %{public}s", path.c_str(), error.message().c_str());
    return false;
  }
  return true;
}

bool ResolveTdJsonSymbols(TdJsonSymbols *symbols) {
  if (symbols == nullptr) {
    return false;
  }
  symbols->create = td_json_client_create;
  symbols->send = td_json_client_send;
  symbols->receive = td_json_client_receive;
  symbols->execute = td_json_client_execute;
  symbols->destroy = td_json_client_destroy;
  return symbols->create != nullptr && symbols->send != nullptr && symbols->receive != nullptr &&
         symbols->destroy != nullptr;
}

bool EnsureTdJsonSymbolsLoaded() {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  if (g_tdJsonSymbols.create != nullptr) {
    return g_tdJsonSymbols.create != nullptr && g_tdJsonSymbols.send != nullptr &&
           g_tdJsonSymbols.receive != nullptr && g_tdJsonSymbols.destroy != nullptr;
  }
  if (!ResolveTdJsonSymbols(&g_tdJsonSymbols)) {
    LOGE("failed to bind tdjson linked symbols");
    g_tdJsonSymbols = TdJsonSymbols();
    return false;
  }
  LOGI("tdjson linked symbols loaded from %{public}s", kTdJsonLibraryName);
  return true;
}

TdBridgeClient *FindTdBridgeClient(long long handle) {
  auto it = g_tdBridgeClients.find(handle);
  if (it == g_tdBridgeClients.end()) {
    return nullptr;
  }
  return &it->second;
}

std::string ProbeTdjsonViaDlopen() {
  TdJsonSymbols symbols;
  if (!ResolveTdJsonSymbols(&symbols)) {
    return BuildPhase0Result(false, "failed to bind linked tdjson symbols");
  }
  if (symbols.execute != nullptr) {
    symbols.execute(nullptr, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
  }

  void *client = symbols.create();
  if (client == nullptr) {
    return BuildPhase0Result(false, "td_json_client_create returned null");
  }

  constexpr const char *kProbeRequest =
      "{\"@type\":\"getTextEntities\",\"text\":\"phase0 probe\",\"@extra\":\"phase0-text-entities\"}";
  symbols.send(client, kProbeRequest);

  std::string lastResult = "receive timeout";
  bool matched = false;
  for (int attempt = 0; attempt < 40; ++attempt) {
    const char *response = symbols.receive(client, 0.25);
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

  symbols.destroy(client);
  return matched ? BuildPhase0Result(true, lastResult) : BuildPhase0Result(false, lastResult);
}

}  // namespace

extern "C" const char *FfiRunTdjsonPhase0Probe() {
  return CopyNativeStringResult(ProbeTdjsonViaDlopen());
}

extern "C" long long FfiTdBridgeCreateClient() {
  LOGI("FfiTdBridgeCreateClient: entering");
  if (!EnsureTdJsonSymbolsLoaded()) {
    LOGE("FfiTdBridgeCreateClient: tdjson symbols unavailable");
    return 0;
  }
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  void *client = g_tdJsonSymbols.create();
  if (client == nullptr) {
    LOGE("FfiTdBridgeCreateClient: td_json_client_create returned null");
    return 0;
  }
  long long handle = g_nextTdHandle++;
  g_tdBridgeClients[handle] = TdBridgeClient{client};
  LOGI("FfiTdBridgeCreateClient: created handle=%{public}lld", handle);
  return handle;
}

extern "C" long long FfiTdBridgeSend(long long handle, const char *requestJson) {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  LOGI("FfiTdBridgeSend: handle=%{public}lld request=%{public}s", handle, SummarizeTdlibPayloadForLog(requestJson).c_str());
  TdBridgeClient *client = FindTdBridgeClient(handle);
  if (client == nullptr || client->client == nullptr || requestJson == nullptr) {
    return 0;
  }
  g_tdJsonSymbols.send(client->client, requestJson);
  return 1;
}

extern "C" const char *FfiTdBridgePoll(long long handle, long long timeoutMs) {
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  TdBridgeClient *client = FindTdBridgeClient(handle);
  if (client == nullptr || client->client == nullptr) {
    return CopyNativeStringResult("");
  }
  double timeoutSeconds = timeoutMs <= 0 ? 0.0 : static_cast<double>(timeoutMs) / 1000.0;
  const char *response = g_tdJsonSymbols.receive(client->client, timeoutSeconds);
  if (response == nullptr) {
    return CopyNativeStringResult("");
  }
  LOGI("FfiTdBridgePoll: response=%{public}s", SummarizeTdlibPayloadForLog(response).c_str());
  return CopyNativeStringResult(response);
}

extern "C" long long FfiTdBridgeDestroy(long long handle) {
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

extern "C" long long FfiTdBridgeSetLogVerbosity(long long level) {
  if (!EnsureTdJsonSymbolsLoaded()) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(g_tdBridgeMutex);
  if (g_tdJsonSymbols.execute == nullptr) {
    return 0;
  }
  std::string request =
      std::string("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":") + std::to_string(level) + "}";
  g_tdJsonSymbols.execute(nullptr, request.c_str());
  return 1;
}

extern "C" long long FfiClearTelegramTdLocalData() {
  bool dbCleared = ClearDirectoryRecursively(BuildTelegramTdDbDirPath());
  bool filesCleared = ClearDirectoryRecursively(BuildTelegramTdFilesDirPath());
  return (dbCleared && filesCleared) ? 1 : 0;
}

extern "C" long long FfiSaveDemoSessionPhone(const char *phoneNumber) {
  return WriteTextFile(BuildStoragePath("telegramCommercialDemoSessionPhone.txt"), phoneNumber) ? 1 : 0;
}

extern "C" const char *FfiLoadDemoSessionPhone() {
  return CopyNativeStringResult(ReadTextFile(BuildStoragePath("telegramCommercialDemoSessionPhone.txt")));
}

extern "C" void FfiClearDemoSessionPhone() {
  ClearTextFile(BuildStoragePath("telegramCommercialDemoSessionPhone.txt"));
}

extern "C" long long FfiSaveTelegramRuntimeConfig(const char *configJson) {
  return WriteTextFile(BuildStoragePath("telegramTdRuntimeConfig.json"), configJson) ? 1 : 0;
}

extern "C" const char *FfiLoadTelegramRuntimeConfig() {
  return CopyNativeStringResult(ReadTextFile(BuildStoragePath("telegramTdRuntimeConfig.json")));
}

extern "C" void FfiClearTelegramRuntimeConfig() {
  ClearTextFile(BuildStoragePath("telegramTdRuntimeConfig.json"));
}

extern "C" long long FfiSaveTelegramSessionKey(const char *sessionKey) {
  return WriteTextFile(BuildStoragePath("telegramTdSessionKey.txt"), sessionKey) ? 1 : 0;
}

extern "C" const char *FfiLoadTelegramSessionKey() {
  return CopyNativeStringResult(ReadTextFile(BuildStoragePath("telegramTdSessionKey.txt")));
}

extern "C" void FfiClearTelegramSessionKey() {
  ClearTextFile(BuildStoragePath("telegramTdSessionKey.txt"));
}

extern "C" void FfiFreeString(const char *str) {
  free(const_cast<char *>(str));
}

extern "C" const char *FfiGetApplicationFilesDir() {
  return CopyNativeStringResult(ResolveAppFilesDir());
}

extern "C" const char *FfiGetOhosDefaultHttpProxyHost() {
  return CopyNativeStringResult(ReadOhosDefaultHttpProxy().host);
}

extern "C" long long FfiGetOhosDefaultHttpProxyPort() {
  return static_cast<long long>(ReadOhosDefaultHttpProxy().port);
}
