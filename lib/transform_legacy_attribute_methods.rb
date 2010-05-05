#transform_legacy_attribute_methods makes attribute aliases that can be used in dynamic finders and attribute hashes. 

#Author: Skye Shaw (sshaw@lucas.cis.temple.edu)
#License: http://www.opensource.org/licenses/mit-license.php

# Inspired by:
# http://stackoverflow.com/questions/538793/legacy-schema-and-dynamic-find-ruby-on-rails/540096#540096

module TransformLegacyAttributeMethods
  VERSION = "0.2"

  mattr_accessor :transformer
  self.transformer = :underscore

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def transform_legacy_attribute_methods(*args, &block) 
      skip = []

      cattr_accessor :transformed_attribute_hash
      self.transformed_attribute_hash = {}
      private :transformed_attribute_hash

      if args.last.is_a?(Hash) 
        args.last.assert_valid_keys(:skip) 
        skip = [ args.pop[:skip] ].flatten
      end

      transformer = block_given? ? block : (args.shift || TransformLegacyAttributeMethods.transformer)

      column_names.each do |name|
	next if skip.include?(name) || skip.include?(name.to_sym)

	transformed_name = transformer.respond_to?(:call) ? transformer.call(name) : name.send(transformer)
	raise "transformer returned nil for column '#{name}'" if transformed_name.nil?
	transformed_attribute_hash[transformed_name.to_s] = name

        define_transformed_attribute_methods(name, transformed_name)
      end

      self.class_eval do
        def [](attr)        
          read_attribute(self.class.real_attribute_name(attr))
        end
    
        def []=(attr, value)
          write_attribute(self.class.real_attribute_name(attr), value)
        end
    
        def attributes_with_transform
          attrs = attributes_without_transform
          transformed_attribute_hash.each do |transformed_name, name|
            attrs[transformed_name] = attrs[name]
          end
          attrs
        end
        alias_method_chain :attributes, :transform
      end

      self.instance_eval do
        #Transformed attribute names have to be returned to their original to be used in the DB query
        def construct_attributes_from_arguments(attribute_names, arguments)
          attributes = {}
          attribute_names.each_with_index do |name, idx| 
            name = real_attribute_name(name)
            attributes[name] = arguments[idx] 
          end
          attributes
        end
        
        def all_attributes_exists?(attribute_names)
          attribute_names = expand_attribute_names_for_aggregates(attribute_names)
          attribute_names.all? { |name| column_methods_hash.include?(name.to_sym) || transformed_attribute_hash.include?(name) }
        end
      end
    end

    def real_attribute_name(name)
      transformed_attribute_hash.include?(name.to_s) ? transformed_attribute_hash[name.to_s] : name
    end

    private
    def define_transformed_attribute_methods(name, transformed_name)
      define_method(transformed_name.to_sym) do
        read_attribute(name)
      end

      define_method("#{transformed_name}=".to_sym) do |value|
        write_attribute(name, value)
      end
      
      define_method("#{transformed_name}?".to_sym) do
        self.send("#{name}?".to_sym)
      end

      define_method("#{transformed_name}_before_type_cast".to_sym) do
        self.send("#{name}_before_type_cast".to_sym)
      end
    end
  end
end
