#include "progress.h"

namespace defyx_cli {

ProgressEvent ParseProgressEvent(const std::string& message) {
  if (message.find("Data: VPN connected") != std::string::npos) {
    return ProgressEvent::connected;
  }
  if (message.find("Data: VPN failed") != std::string::npos) {
    return ProgressEvent::failed;
  }
  if (message.find("Data: VPN stopped") != std::string::npos ||
      message.find("Data: VPN cancelled") != std::string::npos) {
    return ProgressEvent::stopped;
  }
  if (message.find("Data: VPN connecting") != std::string::npos) {
    return ProgressEvent::connecting;
  }
  return ProgressEvent::none;
}

}  // namespace defyx_cli
