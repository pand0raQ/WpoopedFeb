# Uncomment the next line to define a global platform for your project
platform :ios, '16.0'

target 'WpoopedFeb' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Firebase dependencies
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'

  # Pods for WpoopedFeb
end

# Fix for Xcode 15 and CocoaPods
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
