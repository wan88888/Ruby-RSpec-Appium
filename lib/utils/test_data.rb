require 'dotenv/load'

class TestData
  def self.valid_username
    ENV['TEST_USERNAME'] || 'standard_user'
  end
  
  def self.valid_password
    ENV['TEST_PASSWORD'] || 'secret_sauce'
  end
  
  def self.invalid_username
    'locked_out_user'
  end
  
  def self.invalid_password
    'wrong_password'
  end
end 