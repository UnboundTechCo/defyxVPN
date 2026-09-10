#pragma once

#include <string>

namespace defyx_cli {

enum class ProgressEvent {
  none,
  connecting,
  connected,
  failed,
  stopped,
};

ProgressEvent ParseProgressEvent(const std::string& message);

}  // namespace defyx_cli
