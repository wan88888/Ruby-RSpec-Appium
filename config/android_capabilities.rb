require 'dotenv/load'

module Capabilities
  def self.android_capabilities
    {
      caps: {
        platformName: 'Android',
        'appium:platformVersion': ENV['ANDROID_PLATFORM_VERSION'],
        'appium:deviceName': ENV['ANDROID_DEVICE_NAME'],
        'appium:appPackage': ENV['ANDROID_APP_PACKAGE'],
        'appium:appActivity': ENV['ANDROID_APP_ACTIVITY'],
        'appium:automationName': 'UiAutomator2',
        'appium:newCommandTimeout': 3600,
        'appium:noReset': false
      },
      appium_lib: {
        server_url: ENV['ANDROID_APPIUM_SERVER_URL']
      }
    }
  end
end 