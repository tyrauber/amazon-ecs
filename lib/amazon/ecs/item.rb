module Amazon
  class Item

    def self.attr_accessor(*vars)
      @attributes ||= []
      vars.each{|v| @attributes.push v unless @attributes.include?(v) }
      super(*vars)
    end

    def self.attributes
      @attributes
    end

    def attributes
      self.class.attributes
    end

    def set_attribute(elems)
      elems.each do |elem|
        if !(elem.children.empty?)
          name =  elem.name.to_underscore
          self.class.__send__(:attr_accessor, name) unless self.instance_variables.include?("@#{name}".to_sym)
          if elem.children.length == 1 && elem.children.first.text?
            self.__send__("#{name}=", elem.inner_html)
          else
            klass = Object.const_defined?(elem.name.to_sym) ? Object.const_get(elem.name, Class.new(Amazon::Item)) : Object.const_set(elem.name, Class.new(Amazon::Item))
            self.__send__("#{name}=", klass.new(elem))
          end
        end
      end
    end

    def initialize(element=nil)
      return unless element
      set_attribute(element.children)
      return self
    end
  end
end