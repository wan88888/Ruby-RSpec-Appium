require 'dotenv/load'

module Capabilities
  def self.ios_capabilities
    {
      caps: {
        platformName: 'iOS',
        'appium:platformVersion': ENV['IOS_PLATFORM_VERSION'],
        'appium:deviceName': ENV['IOS_DEVICE_NAME'],
        'appium:app': ENV['IOS_APP_PATH'],
        'appium:automationName': 'XCUITest',
        'appium:newCommandTimeout': 3600,
        'appium:noReset': false
      },
      appium_lib: {
        server_url: ENV['IOS_APPIUM_SERVER_URL']
      }
    }
  end
end 