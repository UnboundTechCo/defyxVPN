#include "settings_manager.h"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <unistd.h>
#include <pwd.h>

const char *SettingsManager::kAppName = "DefyxVPN";
const char *SettingsManager::kConfigFileName = "settings.conf";

SettingsManager::SettingsManager() : config_loaded_(false) {}

SettingsManager::~SettingsManager() {}

std::string SettingsManager::GetConfigDir() const
{
    const char *xdg_config = std::getenv("XDG_CONFIG_HOME");
    if (xdg_config && *xdg_config)
    {
        return std::string(xdg_config) + "/defyx";
    }

    const char *home = std::getenv("HOME");
    if (!home)
    {
        struct passwd *pw = getpwuid(getuid());
        if (pw)
        {
            home = pw->pw_dir;
        }
    }

    if (home)
    {
        return std::string(home) + "/.config/defyx";
    }

    return ".config/defyx";
}

std::string SettingsManager::GetConfigPath() const
{
    return GetConfigDir() + "/" + kConfigFileName;
}

std::string SettingsManager::GetAutostartPath() const
{
    const char *xdg_config = std::getenv("XDG_CONFIG_HOME");
    std::string autostart_dir;

    if (xdg_config && *xdg_config)
    {
        autostart_dir = std::string(xdg_config) + "/autostart";
    }
    else
    {
        const char *home = std::getenv("HOME");
        if (!home)
        {
            struct passwd *pw = getpwuid(getuid());
            if (pw)
            {
                home = pw->pw_dir;
            }
        }
        if (home)
        {
            autostart_dir = std::string(home) + "/.config/autostart";
        }
        else
        {
            autostart_dir = ".config/autostart";
        }
    }

    return autostart_dir + "/defyxvpn.desktop";
}

void SettingsManager::EnsureConfigDir() const
{
    std::string dir = GetConfigDir();
    std::error_code ec;
    std::filesystem::create_directories(dir, ec);
}

void SettingsManager::LoadConfig()
{
    if (config_loaded_)
        return;

    std::ifstream file(GetConfigPath());
    if (file.is_open())
    {
        std::stringstream buffer;
        buffer << file.rdbuf();
        cached_config_ = buffer.str();
        file.close();
    }
    config_loaded_ = true;
}

void SettingsManager::SaveConfig() const
{
    EnsureConfigDir();
    std::ofstream file(GetConfigPath());
    if (file.is_open())
    {
        file << cached_config_;
        file.close();
    }
}

bool SettingsManager::ReadBoolValue(const std::string &key, bool defaultValue) const
{
    const_cast<SettingsManager *>(this)->LoadConfig();

    std::istringstream stream(cached_config_);
    std::string line;

    while (std::getline(stream, line))
    {
        size_t pos = line.find('=');
        if (pos != std::string::npos)
        {
            std::string k = line.substr(0, pos);
            std::string v = line.substr(pos + 1);

            // Trim whitespace
            while (!k.empty() && (k.back() == ' ' || k.back() == '\t'))
                k.pop_back();
            while (!k.empty() && (k.front() == ' ' || k.front() == '\t'))
                k.erase(0, 1);
            while (!v.empty() && (v.back() == ' ' || v.back() == '\t' || v.back() == '\n' || v.back() == '\r'))
                v.pop_back();
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t'))
                v.erase(0, 1);

            if (k == key)
            {
                return v == "1" || v == "true" || v == "yes";
            }
        }
    }

    return defaultValue;
}

bool SettingsManager::WriteBoolValue(const std::string &key, bool value)
{
    LoadConfig();

    std::map<std::string, std::string> config;
    std::istringstream stream(cached_config_);
    std::string line;

    while (std::getline(stream, line))
    {
        size_t pos = line.find('=');
        if (pos != std::string::npos)
        {
            std::string k = line.substr(0, pos);
            std::string v = line.substr(pos + 1);

            while (!k.empty() && (k.back() == ' ' || k.back() == '\t'))
                k.pop_back();
            while (!k.empty() && (k.front() == ' ' || k.front() == '\t'))
                k.erase(0, 1);
            while (!v.empty() && (v.back() == ' ' || v.back() == '\t' || v.back() == '\n' || v.back() == '\r'))
                v.pop_back();
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t'))
                v.erase(0, 1);

            config[k] = v;
        }
    }

    config[key] = value ? "1" : "0";

    std::ostringstream out;
    for (const auto &[k, v] : config)
    {
        out << k << "=" << v << "\n";
    }

    cached_config_ = out.str();
    SaveConfig();

    return true;
}

int SettingsManager::ReadIntValue(const std::string &key, int defaultValue) const
{
    const_cast<SettingsManager *>(this)->LoadConfig();

    std::istringstream stream(cached_config_);
    std::string line;

    while (std::getline(stream, line))
    {
        size_t pos = line.find('=');
        if (pos != std::string::npos)
        {
            std::string k = line.substr(0, pos);
            std::string v = line.substr(pos + 1);

            while (!k.empty() && (k.back() == ' ' || k.back() == '\t'))
                k.pop_back();
            while (!k.empty() && (k.front() == ' ' || k.front() == '\t'))
                k.erase(0, 1);
            while (!v.empty() && (v.back() == ' ' || v.back() == '\t' || v.back() == '\n' || v.back() == '\r'))
                v.pop_back();
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t'))
                v.erase(0, 1);

            if (k == key)
            {
                try
                {
                    return std::stoi(v);
                }
                catch (...)
                {
                    return defaultValue;
                }
            }
        }
    }

    return defaultValue;
}

bool SettingsManager::WriteIntValue(const std::string &key, int value)
{
    LoadConfig();

    std::map<std::string, std::string> config;
    std::istringstream stream(cached_config_);
    std::string line;

    while (std::getline(stream, line))
    {
        size_t pos = line.find('=');
        if (pos != std::string::npos)
        {
            std::string k = line.substr(0, pos);
            std::string v = line.substr(pos + 1);

            while (!k.empty() && (k.back() == ' ' || k.back() == '\t'))
                k.pop_back();
            while (!k.empty() && (k.front() == ' ' || k.front() == '\t'))
                k.erase(0, 1);
            while (!v.empty() && (v.back() == ' ' || v.back() == '\t' || v.back() == '\n' || v.back() == '\r'))
                v.pop_back();
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t'))
                v.erase(0, 1);

            config[k] = v;
        }
    }

    config[key] = std::to_string(value);

    std::ostringstream out;
    for (const auto &[k, v] : config)
    {
        out << k << "=" << v << "\n";
    }

    cached_config_ = out.str();
    SaveConfig();

    return true;
}

bool SettingsManager::IsLaunchOnStartupEnabled() const
{
    std::string autostart_path = GetAutostartPath();
    return std::filesystem::exists(autostart_path);
}

bool SettingsManager::SetLaunchOnStartup(bool enable)
{
    std::string autostart_path = GetAutostartPath();
    std::string autostart_dir = std::filesystem::path(autostart_path).parent_path().string();

    if (enable)
    {
        // Create autostart directory if it doesn't exist
        std::error_code ec;
        std::filesystem::create_directories(autostart_dir, ec);

        // Get the executable path
        char exe_path[4096];
        ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
        if (len == -1)
        {
            return false;
        }
        exe_path[len] = '\0';

        // Create .desktop file
        std::ofstream file(autostart_path);
        if (!file.is_open())
        {
            return false;
        }

        file << "[Desktop Entry]\n";
        file << "Type=Application\n";
        file << "Name=DefyxVPN\n";
        file << "Comment=DefyxVPN Application\n";
        file << "Exec=" << exe_path << " --startup\n";
        file << "Icon=defyxvpn\n";
        file << "Terminal=false\n";
        file << "Categories=Network;VPN;\n";
        file << "StartupNotify=false\n";
        file << "X-GNOME-Autostart-enabled=true\n";

        file.close();
        return true;
    }
    else
    {
        // Remove .desktop file
        std::error_code ec;
        std::filesystem::remove(autostart_path, ec);
        return true;
    }
}

bool SettingsManager::GetAutoConnect() const
{
    return ReadBoolValue("AutoConnect", false);
}

bool SettingsManager::SetAutoConnect(bool value)
{
    return WriteBoolValue("AutoConnect", value);
}

bool SettingsManager::GetStartMinimized() const
{
    return ReadBoolValue("StartMinimized", false);
}

bool SettingsManager::SetStartMinimized(bool value)
{
    return WriteBoolValue("StartMinimized", value);
}

bool SettingsManager::GetForceClose() const
{
    return ReadBoolValue("ForceClose", true);
}

bool SettingsManager::SetForceClose(bool value)
{
    return WriteBoolValue("ForceClose", value);
}

bool SettingsManager::GetSoundEffect() const
{
    return ReadBoolValue("SoundEffect", true);
}

bool SettingsManager::SetSoundEffect(bool value)
{
    return WriteBoolValue("SoundEffect", value);
}

int SettingsManager::GetServiceMode() const
{
    return ReadIntValue("ServiceMode", 1);
}

bool SettingsManager::SetServiceMode(int mode)
{
    return WriteIntValue("ServiceMode", mode);
}

bool SettingsManager::GetProxyService() const
{
    return ReadBoolValue("ProxyService", true);
}

bool SettingsManager::SetProxyService(bool value)
{
    return WriteBoolValue("ProxyService", value);
}
