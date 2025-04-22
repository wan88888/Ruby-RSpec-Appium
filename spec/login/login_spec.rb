require_relative '../spec_helper'

describe 'Login Functionality', type: :feature do
  context 'Successful login' do
    it 'should login with valid credentials' do
      expect(@login_page.is_login_page_displayed?).to be true
      
      # Get test data from .env or use default values
      username = TestData.valid_username
      password = TestData.valid_password
      
      # Perform login action
      @login_page.login(username, password)
      
      # Verify successful login
      expect(@products_page.is_products_page_displayed?).to be true
      
      # Verify products page title
      title = @products_page.get_title_text
      expect(title).to include('PRODUCTS')
      
      # Verify products are displayed
      product_count = @products_page.get_product_count
      expect(product_count).to be > 0
    end
  end
  
  context 'Failed login' do
    it 'should show error message with invalid credentials' do
      expect(@login_page.is_login_page_displayed?).to be true
      
      # Get invalid test data
      username = TestData.invalid_username
      password = TestData.invalid_password
      
      # Perform login action with invalid credentials
      @login_page.login(username, password)
      
      # Check that error message is displayed
      error_message = @login_page.get_error_message
      expect(error_message).to include('Username and password do not match')
      
      # Verify we're still on the login page
      expect(@login_page.is_login_page_displayed?).to be true
    end
  end
end 