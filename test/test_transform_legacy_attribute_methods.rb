require 'yaml'
require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_record/fixtures'

TEST_ROOT = File.expand_path(File.dirname(__FILE__))
require "#{TEST_ROOT}/../init.rb"
config = YAML.load_file("#{TEST_ROOT}/database.yml")

ActiveRecord::Base.establish_connection(config['test'])
ActiveRecord::Schema.define do
  create_table 'people', :primary_key => 'SSN', :force => true do |t|
    t.string   'FirstName'
    t.string   'LastName' 
    t.string   'DOB'  
  end

  create_table 'bills', :force => true do |t|  
    t.string  'bill_from'
    t.boolean 'bill_is_late', :default => false
    t.decimal 'bill_amount_due', :percision => 2
    t.belongs_to :person
  end

  create_table 'currencies', :force => true do |t|  
    t.string  'SYMBOL'
    t.string  'NAME' 
  end
end

Fixtures.create_fixtures("#{TEST_ROOT}/fixtures", %w|people bills|)

class Person < ActiveRecord::Base
  has_many :bills
  transform_legacy_attribute_methods :skip => %w|SSN DOB|
end

class Bill < ActiveRecord::Base
  belongs_to :person
  transform_legacy_attribute_methods { |col| col.sub(/^bill_/, '') }
end

class Currency < ActiveRecord::Base
  transform_legacy_attribute_methods lambda { |col| col.downcase }, :skip => :SYMBOL 
end

class TestTransformLegacyAttributeMethods < Test::Unit::TestCase
  def test_transformed_attributes_with_skip_array
    person = Person.new( :last_name => 'Cat', :DOB => '2000-1-1' )

    assert_equal 'Cat', person.LastName
    assert_equal 'Cat', person.last_name
    assert !person.first_name?

    person.FirstName = 'J'
    assert person.first_name?
    assert_equal 'J', person.first_name
    assert_equal '2000-1-1', person.DOB

    person.attributes = { :first_name => 'Seeemji' }
    assert_equal 'Seeemji', person.first_name
    assert_equal 'Seeemji', person.FirstName

    assert_raises(NoMethodError) { person.dob }
    assert_raises(NoMethodError) { person.ssn = 111 }
  end

  def test_block_transformed_attributes
    bill = Bill.new( :from => 'Honda')
    assert_equal 'Honda', bill.from
  end

  def test_proc_transformed_attributes_with_skip
    currency = Currency.new( :NAME => 'Iraqi Dinar' )      
    assert_equal 'Iraqi Dinar', currency.name
    assert_raises(NoMethodError) { currency.symbol }
  end

  def test_build_collection
    person = Person.new
    person.bills.build :from => 'Shiesty Home Owners Association'
    assert_equal 1, person.bills.size
    assert_equal 'Shiesty Home Owners Association', person.bills.first.from
  end

  def test_dynamic_finder
    bill = Bill.find_by_is_late true
    assert bill.is_late
    assert_equal 'Adelitas', bill.from

    person = Person.find_by_first_name_and_last_name_and_SSN 'G.', 'Code', 123123
    assert_equal 'Code', person.last_name
    assert_equal 'G.', person.first_name
    assert_equal 123123, person.SSN
  end
end
