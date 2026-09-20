#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef void (*progress_callback)(char*);

static progress_callback current_callback = NULL;
static int connected = 0;

static char* CopyString(const char* value) {
  const size_t length = strlen(value) + 1;
  char* copy = (char*)malloc(length);
  if (copy != NULL) {
    memcpy(copy, value, length);
  }
  return copy;
}

int StartVPN(const char* cache_dir, const char* flow_line, const char* pattern,
             int deep_scan, int health_check) {
  (void)cache_dir;
  (void)flow_line;
  (void)deep_scan;
  (void)health_check;

  if (pattern == NULL ||
      (strcmp(pattern, "Mock") != 0 && strcmp(pattern, "Bad") != 0)) {
    if (current_callback != NULL) {
      current_callback("Data: VPN failed");
    }
    return 0;
  }

  const char* method_file = getenv("MOCK_DXCORE_METHOD_FILE");
  if (method_file != NULL) {
    FILE* stream = fopen(method_file, "w");
    if (stream != NULL) {
      fputs(pattern, stream);
      fclose(stream);
    }
  }

  if (current_callback != NULL) {
    current_callback("Data: VPN connecting");
    current_callback("Data: Config label: Mock");
  }
  connected = 1;
  if (current_callback != NULL) {
    current_callback("Data: VPN connected");
  }
  return 1;
}

int StopVPN(void) {
  connected = 0;
  if (current_callback != NULL) {
    current_callback("Data: VPN stopped");
  }
  return 1;
}

void Stop(void) {
  connected = 0;
}

long long MeasurePing(void) {
  return 42;
}

char* GetFlag(void) {
  return CopyString("xx");
}

void SetAsnName(void) {}

void SetTimeZone(float time_zone) {
  (void)time_zone;
}

char* GetFlowLine(int is_test) {
  (void)is_test;
  return CopyString(
      "{\"version\":{},\"flowLine\":"
      "[{\"label\":\"Mock\",\"enabled\":true}]}");
}

char* GetCachedFlowLine(void) {
  return GetFlowLine(0);
}

char* DecodeAndVerifyFlowline(const char* flow_line) {
  (void)flow_line;
  return CopyString("");
}

char* GetVpnStatus(void) {
  return CopyString(connected ? "connected" : "disconnected");
}

void SetProgressCallback(progress_callback callback) {
  current_callback = callback;
}

void SetVerboseLogging(int enabled) {
  (void)enabled;
}

void FreeString(char* value) {
  free(value);
}

void SetConnectionMethod(const char* method) {
  (void)method;
}

void SetCacheDir(const char* cache_dir) {
  (void)cache_dir;
}

int IsTunnelRunning(void) {
  return connected;
}
