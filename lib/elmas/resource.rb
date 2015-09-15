require File.expand_path("../utils", __FILE__)
require File.expand_path("../exception", __FILE__)
require File.expand_path("../uri", __FILE__)
require File.expand_path("../sanitizer", __FILE__)

module Elmas
  module Resource
    include UriMethods
    include Sanitizer

    attr_accessor :attributes, :url
    attr_reader :response

    def initialize(attributes = {})
      @attributes = Utils.normalize_hash(attributes)
      @filters = []
      @query = []
    end

    def id
      @attributes[:id]
    end

    def find_all(options = {})
      @order_by = options[:order_by]
      @select = options[:select]
      get(uri([:order, :select]))
    end

    # Pass filters in an array, for example 'filters: [:id, :name]'
    def find_by(options = {})
      @filters = options[:filters]
      @order_by = options[:order_by]
      @select = options[:select]
      get(uri([:order, :select, :filters]))
    end

    def find
      return nil unless id?
      get(uri([:id]))
    end

    # Normally use the url method (which applies the filters) but sometimes you only want to use the base path or other paths
    def get(uri = self.uri)
      @response = Elmas.get(URI.unescape(uri.to_s))
    end

    def valid?
      valid = true
      mandatory_attributes.each do |attribute|
        valid = @attributes.key? attribute
      end
      valid
    end

    def id?
      !@attributes[:id].nil?
    end

    def save
      attributes_to_submit = sanitize
      if valid?
        if id?
          return @response = Elmas.put(basic_identifier_uri, params: attributes_to_submit)
        else
          return @response = Elmas.post(base_path, params: attributes_to_submit)
        end
      else
        Elmas.error("Invalid Resource #{self.class.name}, attributes: #{@attributes.inspect}")
        Elmas::Response.new(Faraday::Response.new(status: 400, body: "Invalid Request"))
      end
    end

    def delete
      return nil unless id?
      Elmas.delete(basic_identifier_uri)
    end

    # Getter/Setter for resource
    def method_missing(method, *args, &block)
      yield if block
      if /^(\w+)=$/ =~ method
        set_attribute($1, args[0])
      else
        nil unless @attributes[method.to_sym]
      end
      @attributes[method.to_sym]
    end

    private

    def set_attribute(attribute, value)
      @attributes[attribute.to_sym] = value if valid_attribute?(attribute)
    end

    def valid_attribute?(attribute)
      valid_attributes.include?(attribute.to_sym)
    end

    def valid_attributes
      @valid_attributes ||= mandatory_attributes.inject(other_attributes, :<<)
    end
  end
end
