require File.expand_path('../include.rb', __FILE__)
include Mod

module M
  class A
    def p
      puts "foo"
    end

    def self.x
      puts "foo"
    end
  end
end

M::A.x
