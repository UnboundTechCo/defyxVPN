#pragma once

#include <string>
#include <vector>

namespace defyx_cli {

enum class Command {
  connect,
  status,
  disconnect,
  help,
  version,
};

struct Options {
  Command command = Command::help;
  std::string core_library;
  std::string cache_directory;
  std::string flowline_file;
  std::string pattern;
  std::string listen_address = "127.0.0.1";
  int listen_port = 5000;
  bool deep_scan = false;
  bool health_check = false;
  std::string health_check_url =
      "https://speed.cloudflare.com/__down?bytes=65536";
  int health_check_min_bytes = 65536;
  int health_check_timeout_seconds = 20;
  bool cached_flowline = false;
  bool test_flowline = false;
  bool verbose = false;
  bool quiet = false;
  int timeout_seconds = 0;
};

struct ParseResult {
  Options options;
  std::string error;

  bool ok() const { return error.empty(); }
};

Options OptionsFromEnvironment();
ParseResult ParseOptions(const std::vector<std::string>& arguments,
                         const Options& defaults);
std::string Usage();

}  // namespace defyx_cli
