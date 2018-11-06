require 'optparse'
require 'puppet'
require 'yaml'

# The location of enterprise modules varies from version to version.

enterprise_modules = ['pe_infrastructure', 'pe_install', 'pe_manager']
env_mod = '/opt/puppetlabs/server/data/environments/enterprise/modules'
ent_mod = '/opt/puppetlabs/server/data/enterprise/modules'
enterprise_module_paths = [env_mod, ent_mod]
enterprise_module_paths.each do |enterprise_module_path|
  next unless File.directory?(enterprise_module_path)
  enterprise_modules.each do |enterprise_module|
    enterprise_module_lib = "#{enterprise_module_path}/#{enterprise_module}/lib"
    next if $LOAD_PATH.include?(enterprise_module_lib)
    Puppet.debug _("Adding %{enterprise_module} to LOAD_PATH: %{enterprise_module_lib}") % { enterprise_module: enterprise_module, enterprise_module_lib: enterprise_module_lib }
    $LOAD_PATH.unshift(enterprise_module_lib)
  end
end

require_relative 'calculate'
require_relative 'inventory'
require_relative 'query'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: tune.rb [options]'
  opts.separator ''
  opts.separator 'Summary: Inspect infrastructure and output optimized settings (parameters)'
  opts.separator ''
  opts.separator 'Options:'
  opts.separator ''
  options[:common] = false
  opts.on('--common', 'Extract common settings from node-specific settings') do
    options[:common] = true
  end
  options[:current] = false
  opts.on('--current', 'Output currently-defined settings (not including defaults)') do
    options[:current] = true
  end
  options[:debug] = false
  opts.on('--debug', 'Enable logging of debug information') do
    options[:debug] = true
  end
  options[:estimate] = false
  opts.on('--estimate', 'Output estimated capacity summary') do
    options[:estimate] = true
  end
  options[:force] = false
  opts.on('--force', 'Do not enforce minimum system requirements') do
    options[:force] = true
  end
  opts.on('--hiera DIRECTORY', 'Output Hiera YAML files to the specified directory') do |hi|
    options[:hiera] = hi
  end
  opts.on('--inventory FILE', 'Use a YAML file to define infrastructure nodes') do |no|
    options[:inventory] = no
  end
  options[:local] = false
  opts.on('--local', 'Query the local system to define a monolithic infrastructure master node') do
    options[:local] = true
  end
  opts.on('--memory_per_jruby MB', 'Amount of RAM to allocate for each Puppet Server JRuby') do |me|
    options[:memory_per_jruby] = me
  end
  opts.on('--memory_reserved_for_os MB', 'Amount of RAM to reserve for the operating system') do |mo|
    options[:memory_reserved_for_os] = mo
  end
  opts.on('-h', '--help', 'Display help') do
    puts opts
    puts
    exit 0
  end
end
parser.parse!

Puppet.initialize_settings
Puppet::Util::Log.newdestination :console
Puppet.debug = options[:debug]

Puppet.debug _("Command Options: %{options}") % { options: options }

Tune = PuppetX::Puppetlabs::Tune.new(options)

Puppet.warning "Unable to identify Database Hosts or tune PostgreSQL services in PE 2017.x and older\n" unless Tune.pe_2018_or_newer?

if options[:current]
  Tune.output_current_settings
else
  Tune.output_optimized_settings
end