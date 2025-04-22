require 'appium_lib'

class BasePage
  def initialize(driver)
    @driver = driver
  end

  # 智能查找元素方法，支持多种定位策略
  def find_element(locator, timeout = 10, retries = 3)
    try_find_element(locator, timeout)
  rescue => e
    # 如果首次尝试失败，尝试使用重试机制
    if retries > 0
      puts "Element not found with #{locator}, retrying... (#{retries} attempts left)"
      sleep 1
      find_element(locator, timeout, retries - 1)
    else
      # 如果是iOS平台，尝试备用定位策略
      if is_ios? && locator[:accessibility_id]
        puts "Trying alternative iOS locator strategy for #{locator[:accessibility_id]}"
        begin
          # 尝试使用class chain
          class_chain = "**/XCUIElementTypeAny[`name == \"#{locator[:accessibility_id]}\"`]"
          return @driver.find_element('-ios class chain': class_chain)
        rescue => e2
          # 尝试使用predicate string
          predicate = "name == '#{locator[:accessibility_id]}'"
          begin
            return @driver.find_element('-ios predicate string': predicate)
          rescue => e3
            # 所有尝试都失败，抛出原始异常
            raise e
          end
        end
      else
        raise e
      end
    end
  end

  # 尝试查找元素
  def try_find_element(locator, timeout)
    wait = Selenium::WebDriver::Wait.new(timeout: timeout)
    wait.until { @driver.find_element(locator) }
  end

  def find_elements(locator, timeout = 5)
    begin
      wait = Selenium::WebDriver::Wait.new(timeout: timeout)
      wait.until { @driver.find_elements(locator).size > 0 }
      @driver.find_elements(locator)
    rescue
      []
    end
  end

  def tap_element(locator, timeout = 10)
    element = find_element(locator, timeout)
    element.click
  rescue => e
    puts "Error tapping element: #{e.message}"
    # 截图帮助调试
    screenshot_path = "reports/screenshots/tap_error_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png"
    @driver.save_screenshot(screenshot_path)
    raise e
  end

  def input_text(locator, text, timeout = 10)
    element = find_element(locator, timeout)
    element.clear
    element.send_keys(text)
  rescue => e
    puts "Error inputting text: #{e.message}"
    # 截图帮助调试
    screenshot_path = "reports/screenshots/input_error_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png"
    @driver.save_screenshot(screenshot_path)
    raise e
  end

  def wait_for_element(locator, timeout = 15)
    platform_timeout = is_ios? ? timeout + 5 : timeout # iOS通常需要更长的等待时间
    wait = Selenium::WebDriver::Wait.new(timeout: platform_timeout)
    wait.until { find_element(locator, 1, 0).displayed? }
  rescue Selenium::WebDriver::Error::TimeoutError
    # 截图帮助调试
    screenshot_path = "reports/screenshots/wait_error_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png"
    @driver.save_screenshot(screenshot_path)
    raise "Element not found after waiting #{platform_timeout} seconds: #{locator}"
  end

  def is_element_displayed?(locator, timeout = 5)
    begin
      wait_for_element(locator, timeout)
      true
    rescue
      false
    end
  end

  def get_text(locator, timeout = 10)
    find_element(locator, timeout).text
  end

  def get_platform
    # 从环境变量获取平台
    ENV['PLATFORM']&.downcase&.to_sym || :android
  end

  def is_android?
    get_platform == :android
  end
  
  def is_ios?
    get_platform == :ios
  end
  
  # 滑动屏幕的辅助方法
  def swipe(start_x, start_y, end_x, end_y, duration = 500)
    @driver.execute_script('mobile: swipe', { from: { x: start_x, y: start_y }, to: { x: end_x, y: end_y }, duration: duration })
  end
  
  # 捕获屏幕截图
  def take_screenshot(filename = nil)
    filename ||= "screenshot_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png"
    path = File.join('reports/screenshots', filename)
    @driver.save_screenshot(path)
    path
  end
end 