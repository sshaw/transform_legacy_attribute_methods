require 'transform_legacy_attribute_methods'
ActiveRecord::Base.send(:include, TransformLegacyAttributeMethods)
