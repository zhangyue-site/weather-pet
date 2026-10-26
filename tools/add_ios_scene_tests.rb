#!/usr/bin/env ruby
# Add an app-hosted lifecycle regression to an exported Xcode project.
if ENV['COURTYARD_LEGACY_RUBY'] == '1'
  gem 'CFPropertyList', '3.0.6'
  gem 'rexml', '3.2.6'
end
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV.fetch(0))
app = project.targets.find { |target| target.name == 'Courtyard' }
raise 'Missing Courtyard app target' unless app
name = 'CourtyardSceneTests'
target = project.targets.find { |item| item.name == name } || project.new_target(:unit_test_bundle, name, :ios, '15.0')
source = File.expand_path('../native/ios/tests/SceneLifecycleTests.swift', __dir__)
reference = project.main_group.files.find { |item| item.path == source } || project.main_group.new_file(source)
target.source_build_phase.add_file_reference(reference) unless target.source_build_phase.files_references.include?(reference)
target.add_dependency(app) unless target.dependencies.any? { |dependency| dependency.target == app }
target.build_configurations.each do |config|
  config.build_settings.merge!({ 'SWIFT_VERSION' => '5.0', 'PRODUCT_NAME' => name, 'PRODUCT_MODULE_NAME' => name,
    'GENERATE_INFOPLIST_FILE' => 'YES', 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.weatherpet.scene-tests',
    'CODE_SIGNING_ALLOWED' => 'NO', 'SUPPORTED_PLATFORMS' => 'iphonesimulator',
    'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/Courtyard.app/Courtyard', 'BUNDLE_LOADER' => '$(TEST_HOST)' })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app); scheme.add_build_target(target); scheme.add_test_target(target); scheme.set_launch_target(app)
scheme.save_as(project.path, 'CourtyardSceneQA', true)
