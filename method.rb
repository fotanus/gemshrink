module GemShrink
  # Represents a simple method object
  class Method
    attr_accessor :object, :name, :args, :block
    def initialize(params)
      @object = params[:object]
      @name = params[:name]
      @args = params[:args]
      @block = params[:block]
    end

    def <=>(other)
      if @name < other.name
        self
      elsif @name > other.name
        @other
      else
        if @object > other.object
          self
        else
          other
        end
      end
    end

    def to_s
      "#{@object}.#{@name}"
    end
  end
end
