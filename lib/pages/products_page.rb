require_relative 'base_page'

class ProductsPage < BasePage
  # Element locators
  def products_title
    if is_android?
      { xpath: '//android.view.ViewGroup[@content-desc="test-Cart drop zone"]/android.view.ViewGroup/android.widget.TextView' }
    else
      # iOS提供多种定位策略
      {
        xpath: '//XCUIElementTypeStaticText[@name="PRODUCTS"]',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeStaticText[`name == "PRODUCTS"`]' },
          { 'predicate string': 'name == "PRODUCTS"' }
        ]
      }
    end
  end
  
  def hamburger_menu
    if is_android?
      { accessibility_id: 'test-Menu' }
    else
      # iOS提供多种定位策略
      {
        accessibility_id: 'test-Menu',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeOther[`name == "test-Menu"`]' },
          { xpath: '//XCUIElementTypeOther[@name="test-Menu"]' }
        ]
      }
    end
  end
  
  def product_items
    if is_android?
      { xpath: '//android.view.ViewGroup[@content-desc="test-Item"]' }
    else
      # iOS提供多种定位策略
      {
        accessibility_id: 'test-Item',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeOther[`name CONTAINS "test-Item"`]' },
          { xpath: '//XCUIElementTypeOther[contains(@name, "test-Item")]' }
        ]
      }
    end
  end
  
  # 购物车图标
  def cart_icon
    if is_android?
      { accessibility_id: 'test-Cart' }
    else
      {
        accessibility_id: 'test-Cart',
        alternatives: [
          { 'class chain': '**/XCUIElementTypeOther[`name == "test-Cart"`]' },
          { xpath: '//XCUIElementTypeOther[@name="test-Cart"]' }
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
  def is_products_page_displayed?
    wait_for_products_page
  end
  
  def get_title_text
    begin
      title_element = find_with_alternatives(products_title)
      text = title_element.text
      $logger.info("Products page title: #{text}")
      return text
    rescue => e
      $logger.error("Failed to get products title: #{e.message}")
      take_screenshot("products_title_error.png")
      return ""
    end
  end
  
  def open_hamburger_menu
    $logger.info("Opening hamburger menu")
    find_with_alternatives(hamburger_menu).click
  end
  
  def get_product_count
    begin
      elements = find_elements(product_items)
      count = elements.length
      $logger.info("Found #{count} product items")
      return count
    rescue => e
      $logger.error("Failed to get product count: #{e.message}")
      return 0
    end
  end
  
  # 等待产品页面显示，使用更灵活的方法
  def wait_for_products_page(timeout = 20)
    start_time = Time.now
    $logger.info("Waiting for products page...")
    
    loop do
      begin
        # 尝试找到产品标题
        if is_element_displayed?(products_title, 2)
          $logger.info("Products page displayed successfully")
          return true
        end
      rescue => e
        # 忽略异常，继续尝试
      end
      
      # 另一种检查方法：查找购物车图标
      begin
        if is_element_displayed?(cart_icon, 1)
          $logger.info("Cart icon found, products page is displayed")
          return true
        end
      rescue => e
        # 忽略异常，继续尝试
      end
      
      # 超时检查
      elapsed = Time.now - start_time
      if elapsed > timeout
        $logger.warn("Timed out waiting for products page after #{elapsed.round(1)} seconds")
        take_screenshot("products_page_timeout.png")
        return false
      end
      
      # 短暂等待后再次尝试
      sleep 1
    end
  end
end 