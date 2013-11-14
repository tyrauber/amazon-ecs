module Amazon
  # Response object returned after a REST call to Amazon service.
  class Response
    
    # XML input is in string format
    def initialize(xml)
      @doc = Nokogiri::XML(xml, nil, 'UTF-8')
      @doc.remove_namespaces!
      return self
    end

    # Return Nokogiri::XML::Document object.
    def doc
      @doc
    end

    # Return true if request is valid.
    def is_valid_request?
      Element.get(@doc, "//IsValid") == "True"
    end

    # Return true if response has an error.
    def has_error?
      !(error.nil? || error.empty?)
    end

    # Return error message.
    def error
      Element.get(@doc, "//Error/Message")
    end
    
    # Return error code
    def error_code
      Element.get(@doc, "//Error/Code")
    end
    
    # Return an array of Amazon::Element item objects.
    def items
      @items ||= (@doc/"Item").collect { |item| Item.new(item) }
    end
    
    # Return the first item (Amazon::Element)
    def first_item
      items.first
    end
    
    # Return current page no if :item_page option is when initiating the request.
    def item_page
      @item_page ||= Element.get(@doc, "//ItemPage").to_i
    end

    # Return total results.
    def total_results
      @total_results ||= Element.get(@doc, "//TotalResults").to_i
    end
    
    # Return total pages.
    def total_pages
      @total_pages ||= Element.get(@doc, "//TotalPages").to_i
    end

    def marshal_dump
      @doc.to_s
    end

    def marshal_load(xml)
      initialize(xml)
    end
  end
end