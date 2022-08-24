class FreestyleType < ActiveRecord::Type::Json
  def type
    :freestyle
  end

  def deserialize(value)
    return value unless value.is_a?(::String) || value.is_a?(::Hash)

    value = if value.is_a?(::Hash)
      value.with_indifferent_access rescue nil
    else
      ActiveSupport::JSON.decode(value).with_indifferent_access rescue nil
    end
    return nil if value.nil?

    begin
      clazz = value[:type].constantize
    rescue
      Rails.logger.error("expected to instantiate type, not expected to use for hash")
      Rails.logger.error(value)
      Rails.logger.error(value.class)
      Rails.logger.error("expected to instantiate type, not expected to use for hash")
      return value
    end

    # instead of a blind rescue, should we allow the class to safely ignore deprecated attributes?
    # something like ignored_columns? maybe, except we have no migration support...
    # for now just break to see the error
    # clazz.new(x.except(:type)) # rescue x
    clazz.new(value) # rescue x
  end

  def serialize(value)
    value.method :serialize
    value.serialize
  rescue NameError
    ActiveSupport::JSON.encode(value) unless value.nil?
  end
end

class FreestyleHashInflatable
  include ActiveModel::Model

  def self.inflate attribute_name
    define_method(attribute_name.to_s+"=") do |val|
      if val.is_a?(::Hash)
        instance_variable_set("@#{attribute_name.to_s}", FreestyleType.new.deserialize(val.with_indifferent_access))
      else
        instance_variable_set("@#{attribute_name.to_s}", val)
      end
    end
  end

  attr_accessor :type

  def initialize(...)
    self.type = type
    super(...)
  end

  def type
    self.class.name
  end

  def serialize
    to_json
  end
end

# example usage
# =============
#
# ActiveRecord::Type.register(:freestyle, FreestyleType)
#
# class ExampleObj < FreestyleHashInflatable # active model base class
#   attr_accessor :bar
#   attr_accessor :dynamic_bar

#   inflate :dynamic_bar
# end
#
# class Boat < ActiveRecord::Base
#   # with a jsonb column named :junk_drawer
#   attribute :junk_drawer, :freestyle
# end
