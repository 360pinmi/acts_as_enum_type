require "acts_as_enum/version"
require 'active_support/concern'
require 'active_record'

module ActsAsEnum
  extend ActiveSupport::Concern
  included do
    include ActiveModel::Validations
  end

  module ClassMethods
    def type_columns(type_columns)
      @type_columns = type_columns
    end

    def type_columns
      @type_columns ||= []
    end

    def acts_as_enum_hash(column, hash)
      type_values = []
      type_names = []
      hash.each{ |k,v|
        type_values << k
        type_names << v
      }
      acts_as_enum(column, type_values, type_names)
    end

    def acts_as_enum(column, type_values=[], type_names=[])
      type_columns << column
      type_values.map!(&:to_sym)
      type_names = type_values if type_names.blank? || type_names.empty?
      raise "acts_as_enum values size not equal to names size." if type_values.size != type_names.size

      define_singleton_method "#{column}_collection".to_sym do
        type_names.zip(type_values)
      end

      define_singleton_method "#{column}_collection_hash".to_sym do
        type_names.zip(type_values).map{|item| { name: item[0], value: item[1] }}
      end

      define_singleton_method "#{column}_collection_as_select_data".to_sym do
        type_names.zip(type_values).map{|item| { name: item[0], id: item[1] }}
      end

      define_singleton_method "#{column}_values".to_sym do
        type_values
      end

      define_singleton_method "#{column}_value".to_sym do |type_name|
        (Hash[type_names.zip(type_values)][type_name] rescue nil)
      end

      define_singleton_method "#{column}_names".to_sym do
        type_names
      end

      define_singleton_method "#{column}_name".to_sym do |type_value|
        (Hash[type_values.zip(type_names)][type_value.to_sym] rescue nil)
      end

      self.class_eval do
        validates column, inclusion: {:in => type_values.map{|value| [value, value.to_s]}.flatten}, :allow_blank => true
        if respond_to?(:table_name) && ActiveRecord::Base.connection.table_exists?(table_name) && ActiveRecord::Base.connection.column_exists?(table_name, column)
          scope "by_#{column}".to_sym, ->(column_param){ where(column.to_sym => column_param) if column_param.present? }
        end
      end

      type_values.each do |type_value|
        define_method "is_#{type_value}?".to_sym do
          self.send(column).try(:to_sym) == type_value.to_sym
        end

        define_method "is_not_#{type_value}?".to_sym do
          self.send(column).try(:to_sym) != type_value.to_sym
        end
      end

      unless self.instance_methods.include?("#{column}_name".to_sym)
        define_method "#{column}_name".to_sym do
          (Hash[type_values.zip(type_names)][(self.send(column).to_sym)] rescue nil)
        end
      end

    end
  end
end
