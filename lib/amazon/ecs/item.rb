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
            klass_name= "Item#{elem.name.gsub(/s$/, '')}".to_sym
            klass = Amazon.const_defined?(klass_name) ? Amazon.const_get(klass_name, Class.new(Amazon::Item)) : Amazon.const_set(klass_name, Class.new(Amazon::Item))
            obj = klass.new()
            objs = []
            elem.children.each do |child|
              if child.children.length == 1
                child_name = child.name.to_underscore
                obj.class.__send__(:attr_accessor, child_name) unless obj.instance_variables.include?("@#{child_name}".to_sym)
                obj.__send__("#{child_name}=", child.inner_html)
              else
                objs.push klass.new(child)
              end
            end
            if objs.empty?
              self.__send__("#{name}=", obj)
            else
              self.__send__("#{name}=", objs)
            end
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