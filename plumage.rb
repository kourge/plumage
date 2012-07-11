#!/usr/bin/ruby

framework 'AppKit'
require 'optparse'

def main
  ARGV << '--help' if ARGV.empty?
  options = {}
  opts_parser = OptionParser.new do |opts|
    script_name = File.split(__FILE__).last
    opts.banner = "Usage: #{script_name} [options] infile [outfile]"

    formats = TerminalColorSettings::ConverterMap.keys
    formats_list = "  (#{formats.join(',')})"

    opts.on('-if', '--input-format=FORMAT', formats,
            'Specify the input format', formats_list) do |inf|
      options[:if] = inf
    end
    opts.on('-of', '--output-format=FORMAT', formats,
            'Specify the output format', formats_list) do |of|
      options[:of] = of
    end
  end

  begin
    opts_parser.parse!
  rescue OptionParser::InvalidOption => e
    warn e.message
    warn opts_parser.help
    exit
  end

  in_file, out_file = ARGV[0], ARGV[1]

  in_dict = NSDictionary.dictionaryWithContentsOfFile(in_file)
  options[:if] ||= TerminalColorSettings.detect(in_dict)
  warn "Couldn't detect input file format" or exit if options[:if].nil?

  input = TerminalColorSettings.new(in_dict, options[:if])
end



class NSPropertyListSerialization
  def self.unarchive(object)
    if object.kind_of?(NSData)
      NSKeyedUnarchiver.unarchiveObjectWithData(object)
    else
      object
    end
  end

  PropertyListNativeTypes = [
    NSArray, NSDictionary, NSString, NSDate, NSNumber, TrueClass, FalseClass
  ]
  def self.archive(object)
    if PropertyListNativeTypes.any? { |type| object.kind_of?(type) }
      object
    else
      NSKeyedArchiver.archivedDataWithRootObject(object)
    end
  end
end



class TerminalColorSettings
  attr_reader :dict

  def initialize(file, format=nil)
    @converter = ConverterMap[format] or raise InvalidFormatError.new

    file = Hash.dictionaryWithContentsOfFile(file) unless file.kind_of?(Hash)
    @dict = @converter.from(file)
  end

  def to_dict(format=nil)
    converter = ConverterMap[format] or raise InvalidFormatError.new
    converter.to(@dict)
  end

  def self.detect(dict)
    return :iterm2 if dict?["Ansi 0 Color"]
    return :terminalapp if dict["type"] == "Window Settings"
    nil
  end


  class InvalidFormatError < ArgumentError
  end


  module TerminalAppConverter
    def self.from(dict)
      Hash[dict.map { |k, v| [k, NSPropertyListSerialization.unarchive(v)] }]
    end

    def self.to(dict)
      h = Hash[dict.map { |k, v| [k, NSPropertyListSerialization.archive(v)] }]
      TerminalDefaultSettings.merge(h)
    end

    TerminalDefaultSettings = {"type" => "Window Settings"}
  end


  module ITermConverter
    def self.from(dict)
      Hash[dict.map { |k, v|
        v = NSColor.colorWithCalibratedRed(v["Red Component"],
          :green => v["Green Component"], :blue => v["Blue Component"],
          :alpha => 1.0
        ) if k.end_with?("Color")
        k = ITermToTerminalMap[k] if ITermToTerminalMap.keys.include?(k)
        [k, v]
      }]
    end

    def self.to(dict)
      Hash[dict.map { |k, v|
        if TerminalToITermMap.keys.include?(k)
          [TerminalToITermMap[k], {
            "Red Component" => v.redComponent,
            "Green Component" => v.greenComponent,
            "Blue Component" => v.blueComponent
          }]
        else [] end
      }]
    end

    ITermToTerminalMap = {
      "Ansi 0 Color" => "ANSIBlackColor",
      "Ansi 1 Color" => "ANSIRedColor",
      "Ansi 2 Color" => "ANSIGreenColor",
      "Ansi 3 Color" => "ANSIYellowColor",
      "Ansi 4 Color" => "ANSIBlueColor",
      "Ansi 5 Color" => "ANSIMagentaColor",
      "Ansi 6 Color" => "ANSICyanColor",
      "Ansi 7 Color" => "ANSIWhiteColor",

      "Ansi 8 Color" => "ANSIBrightBlackColor",
      "Ansi 9 Color" => "ANSIBrightRedColor",
      "Ansi 10 Color" => "ANSIBrightGreenColor",
      "Ansi 11 Color" => "ANSIBrightYellowColor",
      "Ansi 12 Color" => "ANSIBrightBlueColor",
      "Ansi 13 Color" => "ANSIBrightMagentaColor",
      "Ansi 14 Color" => "ANSIBrightCyanColor",
      "Ansi 15 Color" => "ANSIBrightWhiteColor",

      "Background Color" => "BackgroundColor",
      "Bold Color" => "TextBoldColor",
      "Cursor Color" => "CursorColor",
      # "Cursor Text Color" => nil,
      "Foreground Color" => "TextColor",
      # "Selected Text Color" => nil,
      "Selection Color" => "SelectionColor"
    }

    TerminalToITermMap = ITermToTerminalMap.invert
  end


  ConverterMap = {
    :iterm2 => ITermConverter,
    :terminalapp => TerminalAppConverter
  }
end



if __FILE__ == $0
  main()
end



BEGIN {

  module Env
    MACRUBY_FRAMEWORK_BIN = 'MacRuby.framework/Versions/Current/usr/bin/macruby'
    MACRUBY_CANDIDATES = [
      "/System/Library/PrivateFrameworks/#{MACRUBY_FRAMEWORK_BIN}",
      "/Library/Frameworks/#{MACRUBY_FRAMEWORK_BIN}"
    ]

    def self.find_macruby
      MACRUBY_CANDIDATES.each do |path|
        return path if File.exist?(path)
      end
      last_resort = `which macruby`
      last_resort.empty? ? nil : last_resort
    end

    def self.macruby?
      return false unless Kernel.const_defined?(:RUBY_ENGINE)
      Kernel.const_get(:RUBY_ENGINE) == 'macruby'
    end

    def self.relaunch_in_macruby!(fatal=true)
      return if self.macruby?
      macruby = self.find_macruby
      fail "Couldn't find MacRuby" if macruby.nil? and fatal

      args = [__FILE__] + ARGV
      Kernel.exec(macruby, *args)
    end
  end

  Env.relaunch_in_macruby!

}

