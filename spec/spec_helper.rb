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
                 # 对于iOS，使用固定的Bundle ID
                 "com.saucelabs.SwagLabsMobileApp"
               end
      
      $logger.info("Preparing app for test: #{app_id}")
      
      # 为iOS平台增加特殊处理
      if @platform == 'ios'
        # iOS特殊处理：不进行完全重启，而是在测试前尝试回到初始状态
        begin
          # 确保应用处于前台运行状态
          app_state = @driver.app_state(app_id) rescue 0
          
          if app_state != 4 # 如果应用不在前台运行
            # 先尝试激活应用
            $logger.info("Activating iOS app (current state: #{app_state})")
            @driver.activate_app(app_id) rescue nil
            sleep 2
          end
          
          # 尝试通过UI交互回到初始状态（如点击返回按钮或菜单项）
          begin
            # 检查是否在产品页面，如果是，通过菜单退出登录
            if @products_page && @products_page.is_products_page_displayed?(3)
              $logger.info("Found products page, attempting to log out")
              @products_page.open_hamburger_menu rescue nil
              sleep 1
              
              # 尝试查找并点击注销按钮
              logout_locators = [
                {accessibility_id: 'test-LOGOUT'},
                {xpath: '//XCUIElementTypeStaticText[@name="LOGOUT"]'},
                {xpath: "//XCUIElementTypeOther[contains(@name, 'LOGOUT')]"}
              ]
              
              logout_locators.each do |locator|
                begin
                  @driver.find_element(locator).click
                  $logger.info("Clicked logout button")
                  break
                rescue => e
                  # 继续尝试下一个定位器
                end
              end
              
              # 给页面跳转一些时间
              sleep 2
            end
          rescue => ui_err
            $logger.warn("UI interaction error: #{ui_err.message}")
          end
          
          # 检查登录页面是否显示
          login_page_displayed = @login_page.is_login_page_displayed?(5) rescue false
          
          # 如果UI交互无法回到登录页，则强制重启应用
          unless login_page_displayed
            $logger.info("Login page not visible, performing app restart")
            # 使用标准的应用重启方法
            restart_success = DriverFactory.restart_app(@driver, app_id)
            
            if !restart_success
              $logger.warn("Standard restart failed, attempting direct restart")
              begin
                @driver.terminate_app(app_id) rescue nil
                sleep 1
                @driver.activate_app(app_id) rescue nil
                sleep 3
              rescue => restart_err
                $logger.error("Direct restart failed: #{restart_err.message}")
              end
            end
          else
            $logger.info("App is already on login page, no restart needed")
          end
        rescue => e
          $logger.error("iOS app preparation error: #{e.message}")
        end
      else
        # Android使用标准重启方法
        # 为Android平台增加更多重试和等待
        max_restart_attempts = 2
        restart_attempt = 0
        restart_success = false
        
        while restart_attempt < max_restart_attempts && !restart_success
          restart_attempt += 1
          
          if restart_attempt > 1
            $logger.info("Retry attempt #{restart_attempt} to restart Android app")
            sleep 2
          end
          
          # 使用标准方法重启应用
          restart_success = DriverFactory.restart_app(@driver, app_id)
        end
        
        # 如果重启失败，重新创建driver
        if !restart_success
          $logger.warn("Android app restart failed, recreating driver")
          DriverFactory.quit_driver(@driver)
          @driver = DriverFactory.create_driver(@platform)
          @login_page = LoginPage.new(@driver)
          @products_page = ProductsPage.new(@driver)
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
                 # 对于iOS，使用固定的Bundle ID
                 "com.saucelabs.SwagLabsMobileApp"
               end
      
      $logger.info("Closing app after test: #{app_id}")
      
      begin
        # 彻底关闭应用而不是仅仅最小化
        if @platform == 'android'
          @driver.terminate_app(app_id)
          $logger.info("Android app closed successfully")
        else
          # iOS平台使用直接终止方法，完全避免使用reset
          begin
            # 首先尝试直接终止应用
            begin
              result = @driver.terminate_app(app_id)
              $logger.info("iOS app terminated directly with result: #{result}")
            rescue => term_err
              $logger.warn("Standard termination failed: #{term_err.message}")
            end
            
            # 额外检查应用是否仍在运行
            begin
              app_state = @driver.app_state(app_id)
              if app_state > 1 # 如果应用仍在运行
                # 尝试使用executeScript关闭应用
                @driver.execute_script('mobile: terminateApp', { bundleId: app_id })
                $logger.info("Used executeScript to terminate iOS app")
              else
                $logger.info("iOS app is already closed (state: #{app_state})")
              end
            rescue => state_err
              $logger.warn("App state check failed: #{state_err.message}")
            end
          rescue => e
            $logger.error("All iOS app termination methods failed: #{e.message}")
          end
        end
      rescue => e
        $logger.error("Failed to close app: #{e.message}")
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