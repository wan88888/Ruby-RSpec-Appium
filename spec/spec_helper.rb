require 'rspec'
require 'appium_lib'
require 'dotenv/load'
require 'logger'
require 'rspec/core/formatters/html_formatter'

require_relative '../lib/utils/driver_factory'
require_relative '../lib/pages/login_page'
require_relative '../lib/pages/products_page'
require_relative '../lib/utils/test_data'

# 创建必要的目录
Dir.mkdir('logs') unless Dir.exist?('logs')
Dir.mkdir('reports') unless Dir.exist?('reports')
Dir.mkdir('reports/screenshots') unless Dir.exist?('reports/screenshots')
Dir.mkdir('reports/html') unless Dir.exist?('reports/html')

# 配置日志
$logger = Logger.new('logs/test_execution.log')
$logger.level = Logger::INFO

RSpec.configure do |config|
  # RSpec 配置
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # 添加HTML格式化器配置
  config.add_formatter('html', 'reports/html/report.html')
  
  # 每个上下文前设置驱动
  config.before(:context) do |context|
    @platform = ENV['PLATFORM'] || 'android'
    $logger.info("Starting tests on platform: #{@platform}")
    
    # 检查Appium服务器是否可用
    begin
      # 创建driver
      @driver = DriverFactory.create_driver(@platform)
      $logger.info("Driver created successfully")
      
      # 检查设备是否就绪
      if DriverFactory.device_ready?(@driver)
        $logger.info("Device is ready")
      else
        $logger.error("Device is not ready!")
      end
      
      # 初始化页面对象
      @login_page = LoginPage.new(@driver)
      @products_page = ProductsPage.new(@driver)
    rescue => e
      $logger.error("Failed to setup driver: #{e.message}")
      $logger.error(e.backtrace.join("\n"))
      raise e
    end
  end
  
  # 每个测试用例前重启应用
  config.before(:each) do
    if @driver
      # 获取应用ID
      app_id = if @platform == 'android'
                 ENV['ANDROID_APP_PACKAGE']
               else
                 ENV['IOS_APP_PATH']
               end
      
      $logger.info("Restarting app: #{app_id}")
      
      # 为iOS平台增加更多重试和等待
      max_restart_attempts = @platform == 'ios' ? 3 : 1
      restart_attempt = 0
      restart_success = false
      
      while restart_attempt < max_restart_attempts && !restart_success
        restart_attempt += 1
        
        if restart_attempt > 1
          $logger.info("Retry attempt #{restart_attempt} to restart app")
          sleep 3 # 在重试前增加额外等待
        end
        
        # 使用新方法重启应用
        restart_success = DriverFactory.restart_app(@driver, app_id)
        
        # 如果重启失败且是iOS，尝试额外的恢复步骤
        if !restart_success && @platform == 'ios'
          $logger.warn("iOS app restart attempt #{restart_attempt} failed, trying additional recovery")
          
          begin
            # 检查应用是否可接受警告框
            begin
              @driver.switch_to.alert.accept
              $logger.info("Accepted alert dialog")
            rescue => alert_err
              # 忽略没有警告框的错误
            end
            
            # 短暂等待以查看是否已经恢复
            sleep 2
            
            # 检查页面状态
            begin
              @driver.get_page_source
              $logger.info("App appears responsive after recovery attempt")
              restart_success = true
            rescue => source_err
              $logger.warn("App still not responsive: #{source_err.message}")
            end
          rescue => recovery_err
            $logger.warn("Additional recovery failed: #{recovery_err.message}")
          end
        end
      end
      
      # 如果所有重启尝试都失败，重新创建driver
      if !restart_success
        $logger.warn("App restart failed after #{restart_attempt} attempts, recreating driver")
        DriverFactory.quit_driver(@driver)
        @driver = DriverFactory.create_driver(@platform)
        @login_page = LoginPage.new(@driver)
        @products_page = ProductsPage.new(@driver)
        
        # 对iOS额外等待以确保应用启动完成
        if @platform == 'ios'
          $logger.info("Waiting additional time for iOS app to stabilize")
          sleep 5
        end
      end
    end
  end
  
  # 每个测试用例后关闭应用
  config.after(:each) do
    if @driver
      app_id = if @platform == 'android'
                 ENV['ANDROID_APP_PACKAGE']
               else
                 # 对于iOS，尝试使用更可靠的方式获取bundle ID
                 ENV['IOS_BUNDLE_ID'] || "com.saucelabs.SwagLabsMobileApp" || ENV['IOS_APP_PATH']
               end
      
      $logger.info("Closing app after test: #{app_id}")
      
      begin
        # 彻底关闭应用而不是仅仅最小化
        if @platform == 'android'
          @driver.terminate_app(app_id)
          $logger.info("Android app closed successfully")
        else
          # iOS平台使用增强的终止方法
          if DriverFactory.terminate_app_safely(@driver, app_id)
            $logger.info("iOS app closed successfully")
          else
            $logger.warn("Could not terminate iOS app with standard method")
            # 尝试使用Appium reset作为后备方案
            begin
              @driver.reset
              $logger.info("Used driver reset as fallback for iOS")
            rescue => reset_err
              $logger.warn("Reset fallback also failed: #{reset_err.message}")
            end
          end
        end
      rescue => e
        $logger.error("Failed to close app: #{e.message}")
        
        # 对于iOS，即使出现错误也不要急于放弃
        if @platform == 'ios'
          $logger.info("Attempting alternative iOS app termination")
          begin
            DriverFactory.close_all_apps(@driver)
          rescue => alt_err
            $logger.error("Alternative termination also failed: #{alt_err.message}")
          end
        end
      end
    end
  end
  
  # 每个上下文后清理驱动
  config.after(:context) do
    if @driver
      $logger.info("Quitting driver after test context")
      DriverFactory.quit_driver(@driver)
    end
  end
  
  # 测试失败时截图
  config.after(:example, :status => :failed) do |example|
    if @driver
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      screenshot_path = "reports/screenshots/failure_#{timestamp}.png"
      
      begin
        @driver.save_screenshot(screenshot_path)
        $logger.info("Screenshot saved to: #{screenshot_path}")
        
        # 保存到测试报告中
        example.metadata[:screenshot] = screenshot_path
        
        # 获取页面源码并保存
        begin
          page_source = @driver.get_source
          source_path = "reports/screenshots/source_#{timestamp}.xml"
          File.write(source_path, page_source)
          $logger.info("Page source saved to: #{source_path}")
        rescue => e
          $logger.error("Failed to capture page source: #{e.message}")
        end
      rescue => e
        $logger.error("Failed to capture screenshot: #{e.message}")
      end
    end
  end
end 