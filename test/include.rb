puts "being executed!"
module Mod
  class Clas
    def inst_met
      puts "foo"
    end

    def self.class_met
      puts "foo"
    end
  end
end

Mod::Clas.new.inst_met
