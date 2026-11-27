# Switches the targets of an Xcode project to manual signing, for CI.
#
#   ruby manual_signing.rb ios/Runner.xcodeproj < settings.json
#
# settings.json: {"configuration", "team", "identity",
#                 "profiles": {bundle id: {"uuid", "name"}}}
#
# Every target whose bundle id has a profile signs with it in that build
# configuration. Fails unless each profile is used. Uses the xcodeproj gem,
# which comes with CocoaPods.

require 'json'

begin
  require 'xcodeproj'
rescue LoadError
  abort 'manual_signing.rb needs the xcodeproj gem, which CocoaPods installs.'
end

project_path = ARGV.fetch(0)
settings = JSON.parse($stdin.read)
profiles = settings.fetch('profiles')

project = Xcodeproj::Project.open(project_path)
used = []

project.native_targets.each do |target|
  configuration = target.build_configurations.find { |c| c.name == settings.fetch('configuration') }
  next unless configuration

  build_settings = configuration.build_settings
  bundle_id = build_settings['PRODUCT_BUNDLE_IDENTIFIER']
  profile = profiles[bundle_id]
  next unless profile

  # Drop SDK-conditional values in the target, which would win over the
  # plain ones. (Plain target values do win over the project's
  # "CODE_SIGN_IDENTITY[sdk=iphoneos*]".)
  build_settings.delete_if do |key, _|
    key.start_with?('CODE_SIGN_IDENTITY[', 'DEVELOPMENT_TEAM[', 'PROVISIONING_PROFILE_SPECIFIER[')
  end
  build_settings['CODE_SIGN_STYLE'] = 'Manual'
  build_settings['DEVELOPMENT_TEAM'] = settings.fetch('team')
  build_settings['CODE_SIGN_IDENTITY'] = settings.fetch('identity')
  build_settings['PROVISIONING_PROFILE_SPECIFIER'] = profile.fetch('uuid')

  used << bundle_id
  puts "#{target.name} (#{bundle_id}): manual signing with \"#{profile.fetch('name')}\""
end

unused = profiles.keys - used
unless unused.empty?
  abort "No target of #{project_path} has the bundle id #{unused.join(', ')} " \
        "in the #{settings.fetch('configuration')} configuration."
end

project.save
