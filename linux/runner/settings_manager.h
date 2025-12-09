#pragma once

#include <string>

// Linux equivalent of Windows RegistryManager
// Uses config files in ~/.config/defyx/ for persistent storage
class SettingsManager
{
public:
    SettingsManager();
    ~SettingsManager();

    // Launch on startup operations
    bool IsLaunchOnStartupEnabled() const;
    bool SetLaunchOnStartup(bool enable);

    // Application preferences operations
    bool GetAutoConnect() const;
    bool SetAutoConnect(bool value);

    bool GetStartMinimized() const;
    bool SetStartMinimized(bool value);

    bool GetForceClose() const;
    bool SetForceClose(bool value);

    bool GetSoundEffect() const;
    bool SetSoundEffect(bool value);

    int GetServiceMode() const;
    bool SetServiceMode(int mode);

    bool GetProxyService() const;
    bool SetProxyService(bool value);

private:
    std::string GetConfigDir() const;
    std::string GetConfigPath() const;
    std::string GetAutostartPath() const;

    bool ReadBoolValue(const std::string &key, bool defaultValue) const;
    bool WriteBoolValue(const std::string &key, bool value);
    int ReadIntValue(const std::string &key, int defaultValue) const;
    bool WriteIntValue(const std::string &key, int value);

    void EnsureConfigDir() const;
    void LoadConfig();
    void SaveConfig() const;

    static const char *kAppName;
    static const char *kConfigFileName;

    // Cached values
    mutable bool config_loaded_;
    mutable std::string cached_config_;
};
