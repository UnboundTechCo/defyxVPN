#pragma once

#include <string>

namespace defyx_cli {

struct FlowLineResult {
  std::string value;
  std::string default_pattern;
  std::string error;

  bool ok() const { return error.empty(); }
};

// Converts either a full API response or a raw flowLine object/array into the
// compact JSON payload expected by DXcore's StartVPN function.
FlowLineResult NormalizeFlowLine(const std::string& payload);

}  // namespace defyx_cli
