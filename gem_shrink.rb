#!/usr/bin/env ruby
$VERBOSE = true

require 'ripper'
require 'sorcerer'
require 'set'
require 'ap'

class ShrinkParser < Ripper::SexpBuilder
  attr_accessor :calls, :file_queue, :file_blacklist

  def initialize(file, file_blacklist = %w(zlib etc stringio psych.so strscan date_core bigdecimal io/console))
    @calls = Set.new
    @file_blacklist = file_blacklist
    super(file)
  end

  def on_call(x1,x2,x3)
    unless x1 == :@CHAR
      call = ("#{Sorcerer.source(x1)}.#{Sorcerer.source(x3)}") rescue nil
      @calls << call
      puts "  Found #{call}..." if $VERBOSE
    end
    super
  end

  def on_stmts_add(_,command)
    # Goes through the requires and include the files
    if is_require(command)
      file_path = eval(Sorcerer.source(command_arg(command))) rescue nil
      unless @file_blacklist.include? file_path
        puts "Entering file #{file_path}..." if $VERBOSE
        @file_blacklist << file_path
        get_calls(add_rb(file_path))
      end
    end
    super
  end

  private
  # Check if command is require
  def is_require(command)
    command[1] && command[1][1] == "require"
  end

  # Get first argument from command
  def command_arg(command)
    command[2]
  end

  # get_calls recursivelly from this file
  def get_calls(file_path)
    file_contents = nil
    if file_path[0] == "/"
      file_contents = File.new(file_path).read
    else
      $LOAD_PATH.each do |lp|
        begin
          file_contents = File.new("#{lp}/#{file_path}").read
          break
        rescue Errno::ENOENT
          next
        end
      end
    end
    # TODO: Blacklist core requires
    puts "WARNING: ignoring require #{file_path}" unless file_contents


    if file_contents
      parser = ShrinkParser.new(file_contents, @file_blacklist)
      parser.parse
      @calls.intersection(parser.calls)
    end
  end

  def add_rb(file_path)
    file_path =~ /.rb$/ ? file_path : "#{file_path}.rb"
  end

end

parser = ShrinkParser.new(File.new(ARGV.first).read)
parser.parse
parser.calls.sort.each{|x| puts x}

