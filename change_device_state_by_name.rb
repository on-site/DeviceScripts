#!/usr/bin/env ruby

require 'optparse'

def error(msg)
  STDERR.puts msg
  exit 1
end

def success(msg)
  puts msg
  exit
end

def parse_options(args, options)
  opts = OptionParser.new do |opts|
    # Default values
    options[:verbose] = false
    options[:mode] = :toggle
    options[:device_enable] = true
    options[:name] = nil

    opts.banner = "Usage: change_device_state_by_name.rb [options] [DeviceString]"
    opts.separator "
    DeviceString can be any case-insensitive substring of the device name as it appears in 'xinput list'
    App will attempt to give the matched device a new state using 'xinput set-prop'
    Device state will be toggled by default.  Use -s to set explicitly.
"
    opts.on("-s state", Integer, 'Set "Device Enabled" value directly instead of toggling') do |value|
      options[:mode] = :set
      options[:device_enable] = value != 0
    end

    opts.on("-l", "--list-devices", "Get a list of available devices") do |l|
      options[:mode] = :list
      options[:name] = ""
    end

    opts.on("-v", "--verbose", "Run verbosely") { |v| options[:verbose] = v }
    opts.on_tail("-h", "--help", "Show this message") { success opts }
  end
  opts.parse!
  opts
end

options = {}
opts = parse_options ARGV, options
error opts if ARGV.empty? && options[:name].nil?
options[:name] = ARGV.first
device_list = %x[xinput list]
matches = device_list.scan /^[\s\W]*((?:\S+\s)*?\S*#{options[:name]}\S*(?:\s\S+)*)\s+id=(\d+)/i
# Check for match
error "Cannot find a matching device for string #{options[:name]}!" unless matches.count > 0
# Check for multiple matches
if matches.count > 1
  match_list = matches.map { |x| "\t#{x.first}" }.join "\n"
  success "Device list:\n#{match_list}" if options[:mode] == :list
  error "Ambiguous device name.  Possible matches are:\n#{match_list}"
end

device_name, id = matches.first
val = 0

if options[:mode] == :toggle
  puts "Toggling #{device_name}" if options[:verbose]
  # Get the state of the device
  props = %x[xinput list-props #{id}]
  props =~ /Device Enabled[^:]*:\s*(\d+)$/
  val = Regexp.last_match 1
  val = 1 - val.to_i
else
  puts "Enabling " + device_name if options[:verbose] and options[:device_enable]
  puts "Disabling " + device_name if options[:verbose] and !options[:device_enable]
  val = 1 if options[:device_enable]
end

command = %{xinput set-prop #{id} "Device Enabled" #{val}}
puts "> #{command}"  if options[:verbose]
result = system command
error "xinput command failed!" unless result
puts "(Success)" if options[:verbose]

if options[:verbose]
  state = if val == 0
            "OFF"
          else
            "ON"
          end
  puts "Device #{device_name} (id=#{id}) is now #{state}"
end
