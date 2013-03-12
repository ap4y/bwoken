require 'bwoken'
require 'rake/clean'

COFFEESCRIPTS      = FileList['integration/coffeescript/**/*.coffee']
COMPILED_COFFEE    = COFFEESCRIPTS.pathmap('%{^integration/coffeescript,integration/tmp/javascript}d/%n.js')
JAVASCRIPTS        = FileList['integration/javascript/**/*.js']
COPIED_JAVASCRIPTS = JAVASCRIPTS.pathmap('%{^integration/javascript,integration/tmp/javascript}d/%f')

BUILD_DIR          = 'build'
IPHONE_DIR         = 'integration/coffeescript/iphone'
IPAD_DIR           = 'integration/coffeescript/ipad'
VENDOR_JS_DIR      = 'integration/javascript'
RESULTS_DIR        = 'integration/tmp/results'
EXAMPLE_COFFEE     = 'integration/coffeescript/iphone/example.coffee'
EXAMPLE_VENDOR_JS  = 'integration/javascript/example_js.js'

directory IPHONE_DIR
directory IPAD_DIR
directory VENDOR_JS_DIR
directory RESULTS_DIR
directory BUILD_DIR

file EXAMPLE_COFFEE => IPHONE_DIR do |t|
  open(t.name, 'w') do |io|
    io.puts '#import ../example_js.js'
    io.puts 'target = UIATarget.localTarget()'
    io.puts 'window = target.frontMostApp().mainWindow()'
  end
end

file EXAMPLE_VENDOR_JS => VENDOR_JS_DIR do |t|
  open(t.name, 'w') do |io|
    io.puts '/* Place your javascript here */'
  end
end

namespace :bwoken do
  desc 'Create bwoken skeleton folders'
  task :init => [IPAD_DIR, RESULTS_DIR, EXAMPLE_COFFEE, EXAMPLE_VENDOR_JS]
end

COMPILED_COFFEE.zip(COFFEESCRIPTS).each do |target, source|
  containing_dir = target.pathmap('%d')
  directory containing_dir
  file target => [containing_dir, source] do
    Bwoken::Coffeescript.compile source, target
  end
end

COPIED_JAVASCRIPTS.zip(JAVASCRIPTS).each do |target, source|
  containing_dir = target.pathmap('%d')
  directory containing_dir
  file target => [containing_dir, source] do
    sh "cp #{source} #{target}"
  end
end

desc 'Compile coffeescript to javascript and copy vendor javascript'
task :coffeescript => (COMPILED_COFFEE + COPIED_JAVASCRIPTS)

CLEAN.include('integration/tmp/javascript')
CLOBBER.include('integration/tmp')



desc 'Compile the workspace'
task :compile, :app_name do |t, args|
  exit_status = Bwoken::Build.new(args[:app_name]).compile
  raise unless exit_status == 0
end


device_families = %w(iphone ipad)

device_families.each do |device_family|

  namespace device_family do
    task :test, [:app_name] => [RESULTS_DIR, :coffeescript] do |t, args|
      if ENV['RUN']
        Bwoken::Script.run_one ENV['RUN'], device_family, args[:app_name]
      else
        Bwoken::Script.run_all device_family, args[:app_name]
      end
    end
  end

  desc "Run tests for #{device_family}"
  task device_family, :app_name do |t, args|
    task("#{device_family}:test").invoke(args[:app_name])
  end

end

desc 'Run all tests without compiling first'
task :test, :app_name do |t, args|
  if ENV['FAMILY']
    Rake::Task[ENV['FAMILY']].invoke(args[:app_name])
  else
    device_families.each do |device_family|
      Rake::Task[device_family].invoke(args[:app_name])
    end
  end
end

task :default => [:compile, :test]
