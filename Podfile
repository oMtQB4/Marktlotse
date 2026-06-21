# CocoaPods setup for "Marktlotse".
# After editing this file run:  pod install
# Then open Marktlotse.xcworkspace (NOT the .xcodeproj).

# Workaround: the bundled Xcodeproj (1.27.0) has no compatibility-version mapping
# for objectVersion 70 (this Xcode 16 project uses it), which otherwise aborts
# `pod install`. Inject the missing entry. Remove once Xcodeproj ships support.
require 'xcodeproj'
if defined?(::Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION) &&
   !::Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION.key?(70)
  patched = ::Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION.merge(70 => 'Xcode 15.0')
  ::Xcodeproj::Constants.send(:remove_const, :COMPATIBILITY_VERSION_BY_OBJECT_VERSION)
  ::Xcodeproj::Constants.const_set(:COMPATIBILITY_VERSION_BY_OBJECT_VERSION, patched.freeze)
end

platform :ios, '17.0'

target 'Marktlotse' do
  use_frameworks!

  # Google ML Kit – official barcode scanning distribution.
  pod 'GoogleMLKit/BarcodeScanning'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      # Avoid CocoaPods build-script sandbox conflicts with Xcode.
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
