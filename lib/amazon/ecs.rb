#--
# Copyright (c) 2010 Herryanto Siatono
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'net/http'
require 'nokogiri'
require 'cgi'
require 'hmac-sha2'
require 'base64'
require 'openssl'
require "amazon/ecs/utility"
require "amazon/ecs/response"
require "amazon/ecs/element"
require "amazon/ecs/item"

module Amazon
  class RequestError < StandardError; end
  
  class Ecs
    VERSION = '3.0.0'
    
    SERVICE_URLS = {
        :us => 'http://ecs.amazonaws.com/onca/xml',
        :uk => 'http://ecs.amazonaws.co.uk/onca/xml',
        :ca => 'http://ecs.amazonaws.ca/onca/xml',
        :de => 'http://ecs.amazonaws.de/onca/xml',
        :jp => 'http://ecs.amazonaws.jp/onca/xml',
        :fr => 'http://ecs.amazonaws.fr/onca/xml',
        :it => 'http://webservices.amazon.it/onca/xml',
        :cn => 'http://webservices.amazon.cn/onca/xml',
        :es => 'http://webservices.amazon.es/onca/xml'
    }
    
    OPENSSL_DIGEST_SUPPORT = OpenSSL::Digest.constants.include?( 'SHA256' ) ||
                             OpenSSL::Digest.constants.include?( :SHA256 )
    
    OPENSSL_DIGEST = OpenSSL::Digest::Digest.new( 'sha256' ) if OPENSSL_DIGEST_SUPPORT
    
    @@options = {
      :version => "2011-08-01",
      :service => "AWSECommerceService"
    }
    
    @@debug = false

    # Default search options
    def self.options
      @@options
    end
    
    # Set default search options
    def self.options=(opts)
      @@options = opts
    end
    
    # Get debug flag.
    def self.debug
      @@debug
    end
    
    # Set debug flag to true or false.
    def self.debug=(dbg)
      @@debug = dbg
    end
    
    def self.configure(&proc)
      raise ArgumentError, "Block is required." unless block_given?
      yield @@options
    end
    
    # Search amazon items with search terms. Default search index option is 'Books'.
    # For other search type other than keywords, please specify :type => [search type param name].
    def self.item_search(terms, opts = {})
      opts[:operation] = 'ItemSearch'
      opts[:search_index] = opts[:search_index] || 'Books'
      
      type = opts.delete(:type)
      if type 
        opts[type.to_sym] = terms
      else 
        opts[:keywords] = terms
      end
      
      self.send_request(opts)
    end

    # Search an item by ASIN no.
    def self.item_lookup(item_id, opts = {})
      opts[:operation] = 'ItemLookup'
      opts[:item_id] = item_id
      
      self.send_request(opts)
    end    

    # Search a browse node by BrowseNodeId
    def self.browse_node_lookup(browse_node_id, opts = {})
      opts[:operation] = 'BrowseNodeLookup'
      opts[:browse_node_id] = browse_node_id
      
      self.send_request(opts)
    end    
    
    # Generic send request to ECS REST service. You have to specify the :operation parameter.
    def self.send_request(opts)
      opts = self.options.merge(opts) if self.options
      
      # Include other required options
      opts[:timestamp] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

      request_url = prepare_url(opts)
      log "Request URL: #{request_url}"
      
      res = Net::HTTP.get_response(URI::parse(request_url))
      unless res.kind_of? Net::HTTPSuccess
        raise Amazon::RequestError, "HTTP Response: #{res.code} #{res.message}"
      end
      Response.new(res.body)
    end
    
    def self.validate_request(opts) 
      raise Amazon::RequestError, "" if opts[:associate_tag]
    end
    
    protected
      def self.log(s)
        return unless self.debug
        if defined? RAILS_DEFAULT_LOGGER
          RAILS_DEFAULT_LOGGER.error(s)
        elsif defined? LOGGER
          LOGGER.error(s)
        else
          puts s
        end
      end
      
    private 
      def self.prepare_url(opts)
        country = opts.delete(:country)
        country = (country.nil?) ? 'us' : country
        request_url = SERVICE_URLS[country.to_sym]
        raise Amazon::RequestError, "Invalid country '#{country}'" unless request_url

        secret_key = opts.delete(:AWS_secret_key)
        request_host = URI.parse(request_url).host
        
        qs = ''
        
        opts = opts.collect do |a,b| 
          [camelize(a.to_s), b.to_s] 
        end
        
        opts = opts.sort do |c,d| 
          c[0].to_s <=> d[0].to_s
        end
        
        opts.each do |e| 
          log "Adding #{e[0]}=#{e[1]}"
          next unless e[1]
          e[1] = e[1].join(',') if e[1].is_a? Array
          # v = URI.encode(e[1].to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
          v = self.url_encode(e[1].to_s)
          qs << "&" unless qs.length == 0
          qs << "#{e[0]}=#{v}"
        end
        
        signature = ''
        unless secret_key.nil?
          request_to_sign="GET\n#{request_host}\n/onca/xml\n#{qs}"
          signature = "&Signature=#{sign_request(request_to_sign, secret_key)}"
        end

        "#{request_url}?#{qs}#{signature}"
      end
      
      def self.url_encode(string)
        string.gsub( /([^a-zA-Z0-9_.~-]+)/ ) do
          '%' + $1.unpack( 'H2' * $1.bytesize ).join( '%' ).upcase
        end
      end
      
      def self.camelize(s)
        s.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
      end
      
      def self.sign_request(url, key)
        return nil if key.nil?
        
        if (OPENSSL_DIGEST_SUPPORT)
          signature = OpenSSL::HMAC.digest(OPENSSL_DIGEST, key, url)
          signature = [signature].pack('m').chomp
        else
          signature = Base64.encode64( HMAC::SHA256.digest(key, url) ).strip
        end
        signature = URI.escape(signature, Regexp.new("[+=]"))
        return signature
      end
  end
end