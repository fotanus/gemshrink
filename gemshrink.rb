#!/usr/bin/env ruby
$VERBOSE = true

require 'ripper'
require 'sorcerer'
require 'set'

require File.expand_path('../method.rb', __FILE__)

module GemShrink

  # Parser that go through the code and extract all the methods used
  #
  # Ripper::SexpBuilder.new("a").parse
  # => [:program, [:stmts_add, [:stmts_new], [:vcall, [:@ident, "a", [1, 0]]]]]
  #
  #
  # Ripper::SexpBuilder.new("a(x)").parse
  # => [:program, [:stmts_add, [:stmts_new], [:method_add_arg, [:fcall, [:@ident, "a", [1, 0]]], [:arg_paren, [:args_add_block, [:args_add, [:args_new], [:vcall, [:@ident, "x", [1, 2]]]], false]]]]]
  #
  #
  # Ripper::SexpBuilder.new("a x").parse
  # => [:program, [:stmts_add, [:stmts_new], [:command, [:@ident, "a", [1, 0]], [:args_add_block, [:args_add, [:args_new], [:vcall, [:@ident, "x", [1, 2]]]], false]]]]
  #
  #
  # Ripper::SexpBuilder.new("a{x}").parse
  # => [:program, [:stmts_add, [:stmts_new], [:method_add_block, [:method_add_arg, [:fcall, [:@ident, "a", [1, 0]]], [:args_new]], [:brace_block, nil, [:stmts_add, [:stmts_new], [:vcall, [:@ident, "x", [1, 2]]]]]]]]
  #
  #
  # Ripper::SexpBuilder.new("a(y){x}").parse
  # => [:program, [:stmts_add, [:stmts_new], [:method_add_block, [:method_add_arg, [:fcall, [:@ident, "a", [1, 0]]], [:arg_paren, [:args_add_block, [:args_add, [:args_new], [:vcall, [:@ident, "y", [1, 2]]]], false]]], [:brace_block, nil, [:stmts_add, [:stmts_new], [:vcall, [:@ident, "x", [1, 5]]]]]]]]

  class MethodsExtractor < Ripper::SexpBuilder
    attr_accessor :calls, :file_queue, :file_blacklist

    def initialize(file, calls = Set.new, file_blacklist = %w(zlib etc stringio psych.so strscan date_core bigdecimal io/console))
      @calls = calls
      @file_blacklist = file_blacklist
      super(file)
    end

    def on_call(x1,x2,x3)
      unless x1 == :@CHAR
        begin
          method = Method.new(:object => Sorcerer.source(x1), :name => Sorcerer.source(x3))
        rescue
          puts "WARNING: Sorcerer not implemented handler" unless $VERBOSE
        end
        @calls << method
        puts "  Found #{method.to_s}..." if $VERBOSE
      end
      super
    end

    def on_stmts_add(x,command)
      # Goes through the requires and include the files
      if is_require(command)
        file_path = eval(Sorcerer.source(command_arg(command))) rescue nil
        unless @file_blacklist.include? file_path
          puts "Entering file #{file_path}..." if $VERBOSE
          @file_blacklist << file_path
          get_calls(file_path)
        end
      end
      "gemshrink parsed"
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

    # Execute code
    def open_file_in_path(file_path)
      file_path = add_rb(file_path)
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
      if file_contents
        yield(file_contents)
      else
        puts "WARNING: ignoring require #{file_path}"
      end
    end

    # get_calls recursivelly from this file
    def get_calls(file_path)
      open_file_in_path(file_path) do |file_contents|
        parser = MethodsExtractor.new(file_contents, @calls, @file_blacklist)
        parser.parse
      end
    end

    # Add rb to the end of file if not present
    def add_rb(file_path)
      file_path =~ /.rb$/ ? file_path : "#{file_path}.rb"
    end
  end
end

parser = GemShrink::MethodsExtractor.new(File.new(ARGV.first).read)
p parser.parse
parser.calls.delete(nil).each{|x| puts x}

