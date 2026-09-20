#include "flowline.h"

#include <json-c/json.h>

#include <cctype>
#include <memory>
#include <string>

namespace defyx_cli {

namespace {

using JsonPointer = std::unique_ptr<json_object, decltype(&json_object_put)>;
using TokenerPointer =
    std::unique_ptr<json_tokener, decltype(&json_tokener_free)>;

std::string Trim(const std::string& input) {
  size_t begin = 0;
  while (begin < input.size() &&
         std::isspace(static_cast<unsigned char>(input[begin])) != 0) {
    ++begin;
  }

  size_t end = input.size();
  while (end > begin &&
         std::isspace(static_cast<unsigned char>(input[end - 1])) != 0) {
    --end;
  }
  return input.substr(begin, end - begin);
}

std::string EnabledLabelPattern(json_object* flowline) {
  json_object* configs = flowline;
  if (json_object_get_type(configs) == json_type_object) {
    json_object* nested = nullptr;
    if (!json_object_object_get_ex(configs, "flowLine", &nested)) {
      return {};
    }
    configs = nested;
  }
  if (json_object_get_type(configs) != json_type_array) {
    return {};
  }

  std::string pattern;
  const size_t count = json_object_array_length(configs);
  for (size_t index = 0; index < count; ++index) {
    json_object* config = json_object_array_get_idx(configs, index);
    json_object* enabled = nullptr;
    json_object* label = nullptr;
    if (json_object_get_type(config) != json_type_object ||
        !json_object_object_get_ex(config, "enabled", &enabled) ||
        json_object_get_type(enabled) != json_type_boolean ||
        json_object_get_boolean(enabled) == 0 ||
        !json_object_object_get_ex(config, "label", &label) ||
        json_object_get_type(label) != json_type_string) {
      continue;
    }

    const char* label_value = json_object_get_string(label);
    if (label_value == nullptr || label_value[0] == '\0') {
      continue;
    }
    if (!pattern.empty()) {
      pattern += ',';
    }
    pattern += label_value;
  }
  return pattern;
}

}  // namespace

FlowLineResult NormalizeFlowLine(const std::string& payload) {
  FlowLineResult result;
  std::string normalized_input = Trim(payload);
  if (normalized_input.size() >= 3 &&
      static_cast<unsigned char>(normalized_input[0]) == 0xef &&
      static_cast<unsigned char>(normalized_input[1]) == 0xbb &&
      static_cast<unsigned char>(normalized_input[2]) == 0xbf) {
    normalized_input.erase(0, 3);
  }

  if (normalized_input.empty()) {
    result.error = "flowline is empty";
    return result;
  }

  TokenerPointer tokener(json_tokener_new(), &json_tokener_free);
  json_tokener_set_flags(tokener.get(), JSON_TOKENER_STRICT);
  JsonPointer root(
      json_tokener_parse_ex(tokener.get(), normalized_input.data(),
                            static_cast<int>(normalized_input.size())),
      &json_object_put);
  const json_tokener_error parse_error =
      json_tokener_get_error(tokener.get());
  if (!root || parse_error != json_tokener_success) {
    result.error =
        std::string("flowline is not valid JSON: ") +
        json_tokener_error_desc(parse_error);
    return result;
  }

  json_object* selected = root.get();
  const json_type root_type = json_object_get_type(root.get());
  if (root_type == json_type_object) {
    json_object* nested_flowline = nullptr;
    json_object* start_line = nullptr;
    const bool is_raw_flowline =
        json_object_object_get_ex(root.get(), "startLine", &start_line);

    if (!is_raw_flowline &&
        json_object_object_get_ex(root.get(), "flowLine", &nested_flowline)) {
      selected = nested_flowline;
    } else if (!is_raw_flowline && nested_flowline == nullptr) {
      result.error =
          "flowline JSON must contain a top-level flowLine property";
      return result;
    }
  } else if (root_type != json_type_array) {
    result.error = "flowline JSON must be an object or array";
    return result;
  }

  const json_type selected_type = json_object_get_type(selected);
  if (selected_type != json_type_object &&
      selected_type != json_type_array) {
    result.error = "the flowLine value must be an object or array";
    return result;
  }

  result.value =
      json_object_to_json_string_ext(selected, JSON_C_TO_STRING_PLAIN);
  result.default_pattern = EnabledLabelPattern(selected);
  return result;
}

}  // namespace defyx_cli
