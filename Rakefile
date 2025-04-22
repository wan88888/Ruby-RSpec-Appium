require 'rspec/core/rake_task'
require 'fileutils'

# Create directory for screenshots
directory 'reports/screenshots'
directory 'reports/html'
directory 'logs'

# Define RSpec tasks
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--format documentation --format html --out reports/html/report.html'
end

namespace :test do
  desc 'Run tests on Android'
  task :android => ['setup:dirs'] do
    ENV['PLATFORM'] = 'android'
    Rake::Task['spec'].execute
  end
  
  desc 'Run tests on iOS'
  task :ios => ['setup:dirs'] do
    ENV['PLATFORM'] = 'ios'
    Rake::Task['spec'].execute
  end
  
  desc 'Run login tests on Android'
  task :android_login => ['setup:dirs'] do
    ENV['PLATFORM'] = 'android'
    system('bundle exec rspec spec/login -fd --format html --out reports/html/android_login_report.html')
  end
  
  desc 'Run login tests on iOS'
  task :ios_login => ['setup:dirs'] do
    ENV['PLATFORM'] = 'ios'
    system('bundle exec rspec spec/login -fd --format html --out reports/html/ios_login_report.html')
  end
  
  desc 'Run parallel tests on Android and iOS'
  task :parallel => ['setup:dirs'] do
    android_pid = Process.spawn('PLATFORM=android bundle exec rspec spec/login -fd --format html --out reports/html/android_report.html')
    ios_pid = Process.spawn('PLATFORM=ios bundle exec rspec spec/login -fd --format html --out reports/html/ios_report.html')
    
    # 等待两个进程完成
    Process.wait(android_pid)
    Process.wait(ios_pid)
    
    puts "Parallel tests completed. Reports generated in reports/html/ directory."
  end
end

namespace :setup do
  desc 'Create necessary directories'
  task :dirs do
    %w[logs reports reports/screenshots reports/html].each do |dir|
      FileUtils.mkdir_p(dir)
    end
  end
  
  desc 'Install dependencies'
  task :install do
    system('bundle install')
  end
end

namespace :report do
  desc 'Open HTML report in browser'
  task :open do
    report_file = 'reports/html/report.html'
    if File.exist?(report_file)
      if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
        system("start #{report_file}")
      elsif RbConfig::CONFIG['host_os'] =~ /darwin/
        system("open #{report_file}")
      elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
        system("xdg-open #{report_file}")
      else
        puts "Report generated at: #{File.expand_path(report_file)}"
      end
    else
      puts "No report file found at #{report_file}"
    end
  end
end

namespace :clean do
  desc 'Clean test results'
  task :results do
    FileUtils.rm_rf('reports/html')
    FileUtils.mkdir_p('reports/html')
  end
  
  desc 'Clean screenshots'
  task :screenshots do
    FileUtils.rm_rf('reports/screenshots')
    FileUtils.mkdir_p('reports/screenshots')
  end
  
  desc 'Clean logs'
  task :logs do
    FileUtils.rm_rf('logs')
    FileUtils.mkdir_p('logs')
  end
  
  desc 'Clean all generated files'
  task :all => [:results, :screenshots, :logs]
end

desc 'Run full test suite on both platforms and generate report'
task :full_test => ['clean:all', 'test:android', 'test:ios', 'report:open']

task :default => 'test:android' 