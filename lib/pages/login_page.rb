require_relative 'base_page'

class LoginPage < BasePage
  # Element locators based on platform
  def username_field
    if is_android?
      { xpath: '//android.widget.EditText[@content-desc="test-Username"]' }
    else
      # iOS提供多种定位策略，提高查找成功率
      {
        accessibility_id: 'test-Username',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeTextField[`name == "test-Username"`]' },
          { 'predicate string': 'name == "test-Username"' },
          { xpath: '//XCUIElementTypeTextField[@name="test-Username"]' }
        ]
      }
    end
  end
  
  def password_field
    if is_android?
      { xpath: '//android.widget.EditText[@content-desc="test-Password"]' }
    else
      # iOS提供多种定位策略
      {
        accessibility_id: 'test-Password',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeSecureTextField[`name == "test-Password"`]' },
          { 'predicate string': 'name == "test-Password"' },
          { xpath: '//XCUIElementTypeSecureTextField[@name="test-Password"]' }
        ]
      }
    end
  end
  
  def login_button
    if is_android?
      { xpath: '//android.view.ViewGroup[@content-desc="test-LOGIN"]' }
    else
      # iOS提供多种定位策略
      {
        accessibility_id: 'test-LOGIN',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeOther[`name == "test-LOGIN"`]' },
          { 'predicate string': 'name == "test-LOGIN"' },
          { xpath: '//XCUIElementTypeOther[@name="test-LOGIN"]' }
        ]
      }
    end
  end
  
  def error_message
    if is_android?
      { xpath: '//android.view.ViewGroup[@content-desc="test-Error message"]/android.widget.TextView' }
    else
      # iOS提供更全面的定位策略
      {
        xpath: '//XCUIElementTypeOther[@name="test-Error message"]/XCUIElementTypeStaticText',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeOther[`name == "test-Error message"`]/**/XCUIElementTypeStaticText' },
          { 'predicate string': 'name CONTAINS "Username and password do not match"' },
          { 'predicate string': 'value CONTAINS "Username and password do not match"' },
          { xpath: '//XCUIElementTypeStaticText[contains(@name, "Username and password")]' },
          { xpath: '//XCUIElementTypeStaticText[contains(@value, "Username and password")]' },
          { accessibility_id: 'Username and password do not match any user in this service.' }
        ]
      }
    end
  end
  
  # 尝试使用多种定位策略查找元素
  def find_with_alternatives(primary_locator)
    begin
      return find_element(primary_locator)
    rescue => e
      if is_ios? && primary_locator[:alternatives]
        $logger.info("Trying alternative locators for iOS element")
        primary_locator[:alternatives].each do |alternative|
          begin
            return find_element(alternative)
          rescue
            next
          end
        end
      end
      # 所有尝试都失败，重新抛出异常
      raise e
    end
  end
  
  # Page actions
  def login(username, password)
    $logger.info("Attempting login with username: #{username}")
    
    # 等待登录页面加载
    wait_for_login_page(20)
    
    # 使用多种定位策略查找元素
    username_el = find_with_alternatives(username_field)
    username_el.clear
    username_el.send_keys(username)
    
    password_el = find_with_alternatives(password_field)
    password_el.clear
    password_el.send_keys(password)
    
    # 点击登录按钮前先截图
    take_screenshot("before_login_tap.png")
    
    find_with_alternatives(login_button).click
    $logger.info("Login button tapped")
  end
  
  def get_error_message
    # 增加等待时间，尤其是对iOS平台
    timeout = is_ios? ? 25 : 15
    
    # 多次尝试查找错误消息
    start_time = Time.now
    max_attempts = 3
    attempts = 0
    
    while attempts < max_attempts
      begin
        # 截图以便调试
        take_screenshot("waiting_for_error_#{attempts}.png")
        
        # 等待错误消息元素出现
        wait_for_element(error_message, timeout / max_attempts)
        
        error_text = find_with_alternatives(error_message).text
        $logger.info("Error message displayed: #{error_text}")
        return error_text
      rescue => e
        attempts += 1
        $logger.warn("Attempt #{attempts} failed to get error message: #{e.message}")
        
        # 在iOS上采用更灵活的方法寻找错误信息
        if is_ios?
          begin
            # 尝试直接查找包含错误文本的任何元素
            any_error = @driver.find_elements(:xpath, "//XCUIElementTypeStaticText")
            any_error.each do |element|
              begin
                text = element.text
                if text && text.include?("Username and password do not match")
                  $logger.info("Found error message using alternative method: #{text}")
                  return text
                end
              rescue => text_error
                # 忽略单个元素的文本获取错误
              end
            end
          rescue => find_error
            # 忽略整体查找错误
          end
        end
        
        # 最后一次尝试时记录错误
        if attempts >= max_attempts
          $logger.error("Failed to get error message after #{max_attempts} attempts: #{e.message}")
          take_screenshot("error_message_final_failure.png")
          return "Error message could not be retrieved"
        end
        
        # 短暂等待后再次尝试
        sleep 2
      end
    end
  end
  
  def is_login_page_displayed?
    wait_for_login_page
  end
  
  # 等待登录页面显示，使用更灵活的方法
  def wait_for_login_page(timeout = 15)
    start_time = Time.now
    loop do
      begin
        # 首先检查用户名字段
        return true if is_element_displayed?(username_field, 2)
      rescue => e
        # 忽略异常，继续尝试
      end
      
      # 超时检查
      elapsed = Time.now - start_time
      if elapsed > timeout
        $logger.warn("Timed out waiting for login page after #{elapsed.round(1)} seconds")
        take_screenshot("login_page_timeout.png")
        return false
      end
      
      # 短暂等待后再次尝试
      sleep 1
    end
  end
end 