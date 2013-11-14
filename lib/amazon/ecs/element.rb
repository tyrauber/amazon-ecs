module Amazon
  class Element
    class << self
      # Return the text value of an element.
      def get(element, path='.')
        return unless element
        result = element.at_xpath(path)
        result = result.inner_html if result
        result
      end
  
      # Return an unescaped text value of an element.
      def get_unescaped(element, path='.')
        result = self.get(element, path)
        CGI::unescapeHTML(result) if result
      end

      # Return an array of values based on the given path.
      def get_array(element, path='.')
        return unless element
    
        result = element/path
        if (result.is_a? Nokogiri::XML::NodeSet) || (result.is_a? Array)
          result.collect { |item| self.get(item) }
        else
          [self.get(result)]
        end
      end

      # Return child element text values of the given path.
      def get_hash(element, path='.')
        return unless element
  
        result = element.at_xpath(path)
        if result
          hash = {}
          result = result.children
          result.each do |item|
            hash[item.name] = item.inner_html
          end 
          hash
        end
      end
    end

    # Returns Nokogiri::XML::Element object    
    def elem
      @element
    end
  
    # Returns a Nokogiri::XML::NodeSet of elements matching the given path. Example: element/"author".
    def /(path)
      elements = @element/path
      return nil if elements.size == 0
      elements
    end

    # Return an array of Amazon::Element matching the given path
    def get_elements(path)
      elements = self./(path)
      return unless elements
      elements = elements.map{|element| Element.new(element)}
    end
  
    # Similar with search_and_convert but always return first element if more than one elements found
    def get_element(path)
      elements = get_elements(path)
      elements[0] if elements
    end

    # Get the text value of the given path, leave empty to retrieve current element value.
    def get(path='.')
      Element.get(@element, path)
    end
  
    # Get the unescaped HTML text of the given path.
    def get_unescaped(path='.')
      Element.get_unescaped(@element, path)
    end
  
    # Get the array values of the given path.
    def get_array(path='.')
      Element.get_array(@element, path)
    end

    # Get the children element text values in hash format with the element names as the hash keys.
    def get_hash(path='.')
      Element.get_hash(@element, path)
    end
  
    def to_s
      elem.to_s if elem
    end
  end
end