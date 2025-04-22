require 'appium_lib'
require_relative '../../config/android_capabilities'
require_relative '../../config/ios_capabilities'

class DriverFactory
  def self.create_driver(platform)
    case platform.to_sym
    when :android
      capabilities = Capabilities.android_capabilities
    when :ios
      capabilities = Capabilities.ios_capabilities
    else
      raise "Unsupported platform: #{platform}"
    end
    
    # 设置noReset为false，启用全新会话
    capabilities[:caps]['appium:noReset'] = false
    # 设置自动接受警告
    capabilities[:caps]['appium:autoAcceptAlerts'] = true if platform.to_sym == :ios
    # 设置命令超时时间
    capabilities[:caps]['appium:newCommandTimeout'] = 120
    
    appium_driver = Appium::Driver.new(capabilities, true)
    appium_driver.start_driver
    
    if platform.to_sym == :android
      # 为Android设置隐式等待
      appium_driver.manage.timeouts.implicit_wait = 10
    else
      # 为iOS设置隐式等待
      appium_driver.manage.timeouts.implicit_wait = 15
    end
    
    appium_driver.driver
  end
  
  def self.quit_driver(driver)
    if driver
      begin
        # 确保在退出会话前关闭所有可能的应用
        close_all_apps(driver)
        # 退出会话
        driver.quit
      rescue => e
        $logger.error("Error quitting driver: #{e.message}")
      end
    end
  end
  
  # 重启APP的方法，替代废弃的reset方法
  def self.restart_app(driver, app_id)
    begin
      platform = driver.capabilities[:platformName]&.downcase || ENV['PLATFORM']&.downcase
      # 处理iOS应用路径问题
      if platform == 'ios' && app_id.include?('/')
        # 从路径中提取应用名称并转换为可能的Bundle ID
        app_name = File.basename(app_id, '.app')
        possible_bundle_id = "com.saucelabs.#{app_name.downcase}"
        $logger.info("iOS app path detected, trying with bundle ID: #{possible_bundle_id} or app name: #{app_name}")
        
        # 尝试不同的ID组合
        [possible_bundle_id, "com.saucelabs.SwagLabsMobileApp", ENV['IOS_BUNDLE_ID'], app_name].compact.uniq.each do |id|
          if terminate_app_safely(driver, id)
            sleep 2
            if activate_app_safely(driver, id)
              $logger.info("Successfully restarted iOS app with ID: #{id}")
              sleep 3
              return true
            end
          end
        end
        
        # 如果所有尝试都失败，尝试使用启动参数重新启动driver
        $logger.warn("Failed to restart iOS app with standard methods, trying driver relaunch")
        return false
      else
        # Android或iOS使用bundle ID的标准流程
        # 确保应用已关闭
        terminate_app_safely(driver, app_id)
        sleep 2
        # 重新启动应用
        activate_app_safely(driver, app_id)
        sleep 3 # 给应用启动一些时间
        $logger.info("Successfully restarted app: #{app_id}")
        return true
      end
    rescue => e
      $logger.error("Failed to restart app: #{e.message}")
      $logger.error(e.backtrace.join("\n"))
      return false
    end
  end
  
  # 安全地终止应用
  def self.terminate_app_safely(driver, app_id)
    return false unless app_id
    
    begin
      platform = driver.capabilities[:platformName]&.downcase || ENV['PLATFORM']&.downcase
      
      # 特殊处理iOS应用路径
      if platform == 'ios' && app_id.include?('/')
        app_name = File.basename(app_id, '.app')
        possible_bundle_id = "com.saucelabs.#{app_name.downcase}"
        $logger.info("For iOS, trying to terminate with bundle ID: #{possible_bundle_id}")
        
        # 对iOS，尝试多种可能的bundle ID
        [possible_bundle_id, "com.saucelabs.SwagLabsMobileApp", ENV['IOS_BUNDLE_ID']].compact.uniq.each do |id|
          begin
            if driver.app_installed?(id)
              driver.terminate_app(id)
              $logger.info("Successfully terminated iOS app with ID: #{id}")
              return true
            end
          rescue => e
            $logger.warn("Failed to terminate iOS app with ID #{id}: #{e.message}")
          end
        end
        
        $logger.warn("Could not terminate iOS app with any known IDs")
        return false
      end
      
      # 标准应用终止流程
      if app_installed?(driver, app_id)
        # 检查应用是否正在运行
        if app_state(driver, app_id) > 0
          result = driver.terminate_app(app_id)
          $logger.info("App terminated: #{app_id}, result: #{result}")
          return true
        else
          $logger.info("App is not running, no need to terminate: #{app_id}")
          return true
        end
      else
        $logger.warn("App is not installed: #{app_id}")
      end
    rescue => e
      $logger.error("Error terminating app: #{e.message}")
      $logger.error(e.backtrace.join("\n"))
    end
    
    false
  end
  
  # 安全地启动应用
  def self.activate_app_safely(driver, app_id)
    return false unless app_id
    
    begin
      platform = driver.capabilities[:platformName]&.downcase || ENV['PLATFORM']&.downcase
      
      # 特殊处理iOS应用路径
      if platform == 'ios' && app_id.include?('/')
        app_name = File.basename(app_id, '.app')
        possible_bundle_id = "com.saucelabs.#{app_name.downcase}"
        $logger.info("For iOS, trying to activate with bundle ID: #{possible_bundle_id}")
        
        # 对iOS，尝试多种可能的bundle ID
        [possible_bundle_id, "com.saucelabs.SwagLabsMobileApp", ENV['IOS_BUNDLE_ID']].compact.uniq.each do |id|
          begin
            if driver.app_installed?(id)
              driver.activate_app(id)
              $logger.info("Successfully activated iOS app with ID: #{id}")
              return true
            end
          rescue => e
            $logger.warn("Failed to activate iOS app with ID #{id}: #{e.message}")
          end
        end
        
        $logger.warn("Could not activate iOS app with any known IDs")
        return false
      end
      
      # 标准应用启动流程
      if app_installed?(driver, app_id)
        result = driver.activate_app(app_id)
        $logger.info("App activated: #{app_id}, result: #{result}")
        return true
      else
        $logger.error("Cannot activate app - not installed: #{app_id}")
        return false
      end
    rescue => e
      $logger.error("Error activating app: #{e.message}")
      $logger.error(e.backtrace.join("\n"))
    end
    
    false
  end
  
  # 检查应用是否已安装
  def self.app_installed?(driver, app_id)
    begin
      return true if driver.app_installed?(app_id)
    rescue => e
      $logger.error("Error checking if app is installed: #{e.message}")
    end
    false
  end
  
  # 获取应用状态
  # 返回值: 0=未安装, 1=未运行, 2=后台运行, 3=前景运行, 4=其他状态
  def self.app_state(driver, app_id)
    begin
      return driver.app_state(app_id)
    rescue => e
      $logger.error("Error getting app state: #{e.message}")
    end
    0 # 默认假设未安装
  end
  
  # 关闭所有应用
  def self.close_all_apps(driver)
    begin
      platform = driver.capabilities[:platformName]&.downcase
      if platform == 'android'
        # 在Android上关闭所有后台应用
        driver.execute_script('mobile: closeApp')
      elsif platform == 'ios'
        # 在iOS上终止当前应用
        current_app = ENV['IOS_BUNDLE_ID'] || ENV['IOS_APP_PATH']
        terminate_app_safely(driver, current_app) if current_app
      end
    rescue => e
      $logger.error("Error closing all apps: #{e.message}")
    end
  end
  
  # 检测设备连接状态
  def self.device_ready?(driver)
    begin
      driver.get_page_source
      true
    rescue => e
      $logger.error("Device connection check failed: #{e.message}")
      false
    end
  end
  
  # 获取设备屏幕尺寸
  def self.get_screen_size(driver)
    begin
      driver.window_size
    rescue => e
      $logger.error("Failed to get screen size: #{e.message}")
      { width: 0, height: 0 }
    end
  end
end 