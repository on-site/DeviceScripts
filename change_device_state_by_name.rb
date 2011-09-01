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

OPTIONS = {
  :verbose => false,
  :mode => :toggle,
  :device_enable => true,
  :name => nil
}

def OPTIONS.list_mode!
  self[:mode] = :list
  self[:name] = ""
end

def OPTIONS.set_mode!(value)
  self[:mode] = :set
  self[:device_enable] = value != 0
end

def OPTIONS.verbose!
  self[:verbose] = true
end

def parse_options(args)
  opts = OptionParser.new do |opts|
    opts.banner = "Usage: change_device_state_by_name.rb [options] [DeviceString]"
    opts.separator "
    DeviceString can be any case-insensitive substring of the device name as it appears in 'xinput list'
    App will attempt to give the matched device a new state using 'xinput set-prop'
    Device state will be toggled by default.  Use -s to set explicitly.
"
    opts.on("-s state", Integer, 'Set "Device Enabled" value directly instead of toggling') { |value| OPTIONS.set_mode! value }
    opts.on("-l", "--list-devices", "Get a list of available devices") { OPTIONS.list_mode! }
    opts.on("-v", "--verbose", "Run verbosely") { OPTIONS.verbose! }
    opts.on_tail("-h", "--help", "Show this message") { success opts }
  end
  opts.parse!
  opts
end

opts = parse_options ARGV
error opts if ARGV.empty? && OPTIONS[:name].nil?
OPTIONS[:name] = ARGV.first
device_list = %x[xinput list]
matches = device_list.scan /^[\s\W]*((?:\S+\s)*?\S*#{OPTIONS[:name]}\S*(?:\s\S+)*)\s+id=(\d+)/i
# Check for match
error "Cannot find a matching device for string #{OPTIONS[:name]}!" unless matches.count > 0
# Check for multiple matches
if matches.count > 1
  match_list = matches.map { |x| "\t#{x.first}" }.join "\n"
  success "Device list:\n#{match_list}" if OPTIONS[:mode] == :list
  error "Ambiguous device name.  Possible matches are:\n#{match_list}"
end

device_name, id = matches.first
value = 0

if OPTIONS[:mode] == :toggle
  puts "Toggling #{device_name}" if OPTIONS[:verbose]
  # Get the state of the device
  props = %x[xinput list-props #{id}]
  props =~ /Device Enabled[^:]*:\s*(\d+)$/
  value = Regexp.last_match 1
  value = 1 - value.to_i
else
  puts "Enabling " + device_name if OPTIONS[:verbose] and OPTIONS[:device_enable]
  puts "Disabling " + device_name if OPTIONS[:verbose] and !OPTIONS[:device_enable]
  value = 1 if OPTIONS[:device_enable]
end

command = %{xinput set-prop #{id} "Device Enabled" #{value}}
puts "> #{command}"  if OPTIONS[:verbose]
result = system command
error "xinput command failed!" unless result
puts "(Success)" if OPTIONS[:verbose]

if OPTIONS[:verbose]
  state = if value == 0
            "OFF"
          else
            "ON"
          end
  puts "Device #{device_name} (id=#{id}) is now #{state}"
end
