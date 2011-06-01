require 'test_helper'
require "date"

class FedExTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = FedEx.new(fixtures(:fedex).merge(:test => true))
  end  
  
  def test_register_user
    assert_nothing_raised do
      response = register_user
      
      assert response.success?
      assert response.test?
      assert_match(/^[a-zA-Z0-9]{16}$/, response.user_key)
      assert_match(/^[a-zA-Z0-9]{25}$/, response.user_password)
    end
  end
  
  def register_canadian_user
    @carrier.register_user(:account_number => '630103983', :client_region => 'CA', :billing_street_lines => '80 FedEx Prkwy', :billing_city => 'Toronto', :billing_state_or_province_code => 'ON', :billing_postal_code => 'L4W5K6', :billing_country_code => 'CA', :user_first_name => 'James', :user_last_name => 'MacAulay', :user_email => 'james@jadedpixel.com', :user_streetlines => '80 FedEx Prkwy', :user_city => 'Toronto', :user_state_or_province_code => 'ON', :user_postal_code => 'L4W5K6', :user_country_code => 'CA', :user_company_name => 'Shopify', :user_phone_number => '9012635448')
  end
  
  def register_us_user
    @carrier.register_user(:account_number => '630054800', :client_region => 'US', :billing_street_lines => '80 FedEx Prkwy', :billing_city => 'AURORA', :billing_state_or_province_code => 'OH', :billing_postal_code => '44202', :billing_country_code => 'US', :user_first_name => 'James', :user_last_name => 'MacAulay', :user_email => 'james@jadedpixel.com', :user_streetlines => '80 FedEx Prkwy', :user_city => 'AURORA', :user_state_or_province_code => 'OH', :user_postal_code => '44202', :user_country_code => 'US', :user_company_name => 'Shopify', :user_phone_number => '9012635448')
  end
  
  def register_user
    register_canadian_user
    # register_us_user
  end
  
  def test_subscribe_user
    register_user
    
    assert_nothing_raised do
      response = @carrier.subscribe_user
      
      assert response.success?
      assert response.test?
      assert_match(/[0-9]{9}/, response.meter_number)
    end
  end
  
  def setup_user(client_account = 'Canadian')
    if client_account == 'Canadian'
      register_canadian_user
    elsif client_account == 'US'
      register_us_user
    end
    
    @carrier.subscribe_user
  end
  
  def test_version_capture
    setup_user
    
    assert_nothing_raised do
      response = @carrier.version_capture('Version Capture Request', :origin_location_id => 'YZRA', :vendor_product_platform => 'Windows OS')
    end
  end
  
  def test_us_to_canada
    setup_user
    
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:ottawa],
                   @packages.values_at(:wii)
                 )
      
      assert response.success?
      assert response.test?
      
      assert !response.rates.empty?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_zip_to_zip_fails
    setup_user
    
    begin
      @carrier.find_rates(
        Location.new(:zip => 40524),
        Location.new(:zip => 40515),
        @packages[:wii]
      )
    rescue ResponseError => e
      assert_match(/country\s?code/i, e.message)
      assert_match(/(missing|invalid)/, e.message)
    end
  end
  
  # FedEx requires a valid origin and destination postal code
  def test_rates_for_locations_with_only_zip_and_country  
    setup_user
    response = @carrier.find_rates(
                 @locations[:bare_beverly_hills],
                 @locations[:bare_ottawa],
                 @packages.values_at(:wii)
               )
  
    assert response.rates.size > 0
  end
  
  def test_rates_for_location_with_only_country_code
    setup_user
    begin
      response = @carrier.find_rates(
                   @locations[:bare_beverly_hills],
                   Location.new(:country => 'CA'),
                   @packages.values_at(:wii)
                 )
    rescue ResponseError => e
      assert_match(/postal code/i, e.message)
      assert_match(/(missing|invalid)/i, e.message)
    end
  end
  
  def test_invalid_recipient_country
    setup_user
    begin
      response = @carrier.find_rates(
                   @locations[:bare_beverly_hills],
                   Location.new(:country => 'JP', :zip => '108-8361'),
                   @packages.values_at(:wii)
                 )
    rescue ResponseError => e
      assert_match(/postal code/i, e.message)
      assert_match(/(missing|invalid)/i, e.message)
    end
  end
  
  def test_ottawa_to_beverly_hills
    setup_user
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_ottawa_to_london
    setup_user
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_beverly_hills_to_london
    setup_user
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_tracking
    setup_user
    
    assert_nothing_raised do
      @carrier.find_tracking_info('798850782313')
    end
  end
  
  
  ### FedEx Tracking Baseline
  
  def test_cde_001
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Calgary',
                             :province => 'AB',
                             :postal_code => 'T2E7R3',
                             :country => 'CA',
                             :address_type => nil) #'residential')
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(149 * 16, [10, 15, 10], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    
    assert_nothing_raised do
      response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDE-001', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'FIRST_OVERNIGHT', :signature_option => 'NO_SIGNATURE_REQUIRED', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
    end
  end
  
  def test_cde_002
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Summerside',
                             :province => 'PE',
                             :postal_code => 'C1N6A1',
                             :country => 'CA',
                             :address_type => 'residential')
    
    ship_date = Date.parse("Friday")
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(49 * 16, [10, 15, 10], :units => :imperial, :value => 200.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDE-002', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'PRIORITY_OVERNIGHT', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cde_003
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'St-Laurent',
                             :province => 'PQ',
                             :postal_code => 'H4S1A1',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(20 * 16, [10, 15, 10], :units => :imperial, :value => 300.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDE-003', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'FIRST_OVERNIGHT', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cde_004
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Edmonton',
                             :province => 'AB',
                             :postal_code => 'T5A 0A7',
                             :country => 'CA',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(30 * 16, [10, 15, 10], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDE-004', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'FEDEX_2_DAY', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cde_005
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Burnaby',
                             :province => 'BC',
                             :postal_code => 'V5H4K7',
                             :country => 'CA',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(70 * 16, [10, 15, 10], :units => :imperial, :value => 200.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDE-005', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'PRIORITY_OVERNIGHT', :signature_option => 'NO_SIGNATURE_REQUIRED', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_nrf_cde_001
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Calgary',
                             :province => 'AB',
                             :postal_code => 'T2E7R3',
                             :country => 'CA',
                             :address_type => 'residential')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(1 * 16, [0, 0, 0], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'NRF-CDE-001', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => Time.now, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_ENVELOPE', :service_type => 'FIRST_OVERNIGHT', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_nrf_cde_002
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Saskatoon',
                             :province => 'SK',
                             :postal_code => 'S7L6H8',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Date.parse("Saturday")
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(120 * 16, [10, 15, 10], :units => :imperial, :value => 200.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'NRF-CDE-002', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :service_type => 'FEDEX_2_DAY', :carrier_code => 'FDXE', :dangerous_goods => {:accessibility => 'INACCESSIBLE', :cargo_aircraft_only => true, :dot_proper_shipping_name => 'Infectious substance, affecting humans (solid)', :dot_id_number => '2814', :quantity => 1, :packing_group => 'Bottle', :units => 'mL', :twenty_four_hour_emergency_response_contact_number => '8005787787', :twenty_four_hour_emergency_response_contact_name => 'Lab Engineer', :dot_hazard_class_or_division => '6.2'})
  end
  
  def test_nrf_cde_003
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Winnipeg',
                             :province => 'MB',
                             :postal_code => 'R2G0A1',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(500 * 16, [10, 15, 10], :units => :imperial, :value => 500.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'NRF-CDE-003', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dangerous_goods => {:accessibility => 'ACCESSIBLE', :cargo_aircraft_only => true, :dot_id_number => '3327', :quantity => 2, :packing_group => 'Drum', :units => 'Kg', :twenty_four_hour_emergency_response_contact_number => '8889950495', :twenty_four_hour_emergency_response_contact_name => 'Director'}, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'FEDEX_1_DAY_FREIGHT', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_nrf_cde_004
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Moncton',
                             :province => 'NB',
                             :postal_code => 'E1E5A1',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Date.parse("Saturday")
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(50 * 16, [10, 15, 10], :units => :imperial, :value => 700.00, :currency => 'CAD')]
    
    # FIXME - pass a Mass object instead of the dry ice weight/units
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'NRF-CDE-004', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :saturday_pickup => true, :dry_ice => {:weight_value => 5, :weight_units => 'KG'}, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'PRIORITY_OVERNIGHT', :signature_option => 'NO_SIGNATURE_REQUIRED', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_nrf_cde_005
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'MISSISSAUGA',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'Winnipeg',
                             :province => 'MB',
                             :postal_code => 'R2G0A1',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(200 * 16, [10, 15, 10], :units => :imperial, :value => 600.00, :currency => 'CAD')]
    
    # FIXME - pass a Mass object instead of the dry ice weight/units
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'NRF-CDE-005', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :hold_at_location => Location.new(:phone => '90126333035', :address1 => 'HAL ADDRESS LINE 1', :city => 'Winnipeg', :province => 'MB', :postal_code => 'R3H1C8'), :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'FEDEX_1_DAY_FREIGHT', :signature_option => 'DIRECT', :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cie_001
    #setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'LANCASTER',
                             :province => 'PA',
                             :postal_code => '17601',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(20 * 16, [0, 0, 0], :units => :imperial, :value => 200.00, :currency => 'CAD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-001', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_PAK', :signature_option => 'DIRECT', :international_delivery => true, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => 'INTERNATIONAL_PRIORITY')
  end
  
  def test_cie_002
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'GUAYNABO',
                             :province => 'PR',
                             :postal_code => '00966',
                             :country => 'US',
                             :address_type => nil)
    
    ship_date = Date.parse('Saturday')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(10 * 16, [0, 0, 0], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    customs_value = 100
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-002', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_BOX', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => 'INTERNATIONAL_ECONOMY', :saturday_pickup => true)
  end
  
  def test_cie_003
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
    
    ship_date = Date.parse('Saturday')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(40 * 16, [0, 0, 0], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    customs_value = 100
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-003', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_BOX', :signature_option => 'NO_SIGNATURE_REQUIRED', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => 'INTERNATIONAL_FIRST', :saturday_pickup => true)
  end
  
  def test_cie_004
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'LANCASTER',
                             :province => 'PA',
                             :postal_code => '17601',
                             :country => 'US',
                             :address_type => nil)
    
    ship_date = Date.parse('Friday')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(20 * 16, [0, 0, 0], :units => :imperial, :value => 440.00, :currency => 'CAD')]
    customs_value = 490
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-004', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_10KG_BOX', :signature_option => 'INDIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => 'INTERNATIONAL_PRIORITY', :saturday_delivery => true)
  end
  
  def test_cie_005
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(1 * 16, [0, 0, 0], :units => :imperial, :value => 300.00, :currency => 'CAD')]
    customs_value = 300
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-005', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_TUBE', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => 'INTERNATIONAL_ECONOMY')
  end
  
  def test_cie_nrf_001
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
    
    ship_date = Date.parse('Saturday')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(250 * 16, [25, 25, 25], :units => :imperial, :value => 250.00, :currency => 'CAD')]
    customs_value = 1500
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-NRF-001', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :saturday_pickup => true, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'INTERNATIONAL_PRIORITY_FREIGHT', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cie_nrf_002
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'MELSBROEK',
                             :province => 'BE',
                             :postal_code => '1820',
                             :country => 'BE',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(70 * 16, [10, 15, 10], :units => :imperial, :value => 1500.00, :currency => 'CAD')]
    customs_value = 1500
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-NRF-002', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dangerous_goods => {:accessibility => 'ACCESSIBLE', :dot_proper_shipping_name => 'Methyl trichloroacetate', :dot_id_number => '2533', :quantity => 1, :packing_group => 'Drum', :units => 'L', :twenty_four_hour_emergency_response_contact_number => '8005557865', :twenty_four_hour_emergency_response_contact_name => 'Director', :cargo_aircraft_only => true, :dot_hazard_class_or_division => '6.1'}, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'INTERNATIONAL_PRIORITY', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cie_nrf_003
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'SINGAPORE',
                             :province => 'SG',
                             :postal_code => '118478',
                             :country => 'SG',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(70 * 16, [10, 15, 10], :units => :imperial, :value => 300.00, :currency => 'CAD')]
    customs_value = 1200
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-NRF-003', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dangerous_goods => {:accessibility => 'INACCESSIBLE', :dot_proper_shipping_name => 'Methyl trichloroacetate', :dot_id_number => '2533', :quantity => 1, :packing_group => 'Drum', :units => 'L', :twenty_four_hour_emergency_response_contact_number => '8005557865', :twenty_four_hour_emergency_response_contact_name => 'Director', :cargo_aircraft_only => true, :dot_hazard_class_or_division => '6.1'}, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'INTERNATIONAL_PRIORITY', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cie_nrf_004
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'SINGAPORE',
                             :province => 'SG',
                             :postal_code => '118478',
                             :country => 'SG',
                             :address_type => nil)
    
    ship_date = Date.parse('Saturday')
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(170 * 16, [40, 40, 40], :units => :imperial, :value => 1800.00, :currency => 'CAD')]
    customs_value = 1800
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-NRF-004', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dry_ice => {:quantity => 1, :weight_units => 'KG', :weight_value => 15}, :saturday_pickup => true, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :service_type => 'INTERNATIONAL_PRIORITY_FREIGHT', :signature_option => 'NO_SIGNATURE_REQUIRED', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cie_nrf_005
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA',
                           :phone => '9012633035')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'NEW DELHI',
                             :province => 'IN',
                             :postal_code => '110001',
                             :country => 'IN',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(20 * 16, [0, 0, 0], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    customs_value = 100
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CIE-NRF-005', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :hold_at_location => Location.new(:phone => '901-263-3035', :address1 => '102 FedEx', :city => 'MUMBAI', :province => 'IN', :postal_code => '411027'), :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'FEDEX_BOX', :service_type => 'INTERNATIONAL_ECONOMY', :signature_option => 'DIRECT', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXE')
  end
  
  def test_cdom_gnd_001
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1751 THOMPSON ST',
                           :city => 'Calgary',
                           :province => 'AB',
                           :postal_code => 'T2E7R3',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'ONTARIO',
                             :province => 'ON',
                             :postal_code => 'M5A3W9',
                             :country => 'CA',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(100 * 16, [10, 15, 10], :units => :imperial, :value => 100.00, :currency => 'CAD')]
    customs_value = 100
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDOM-GND-001', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :signature_option => 'NO_SIGNATURE_REQUIRED', :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => 'FEDEX_GROUND', :cod => {:type => 'CASH', :amount => 100, :currency => 'CAD'})
  end
  
  def test_cdom_nrf_003
    setup_user
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1752 THOMPSON ST',
                           :city => 'Mississauga',
                           :province => 'ON',
                           :postal_code => 'L4W5K6',
                           :country => 'CA')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '81 FEDEX PRKWY',
                             :city => 'Calgary',
                             :province => 'AB',
                             :postal_code => 'T2E7R3',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Time.now
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(100 * 16, [10, 25, 61], :units => :imperial, :value => 250.00, :currency => 'CAD')]
    customs_value = 250
    
    response = @carrier.find_rates(shipper, recipient, packages, :customer_transaction_id => 'CDOM-NRF-003', :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'CA'}, :ship_date => ship_date, :dropoff_type => 'REGULAR_PICKUP', :packaging_type => 'YOUR_PACKAGING', :signature_option => 'DIRECT', :non_standard_container => true, :customs_value => customs_value, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => 'FEDEX_GROUND')
  end
  
  def test_de_001
    setup_user('US')
    
    customer_transaction_id = 'DE-001'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'NORTH LAS VEGAS',
                             :province => 'NV',
                             :postal_code => '89030',
                             :country => 'US',
                             :address_type => nil)
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :cod => {:type => 'ANY', :amount => '100.00', :currency => 'USD'}
    }
    
    height, width, length = 2, 4, 7
    insured_value = 100.00
    weight = 149
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    #service_type = 'COD'
    #service_type = 'STANDARD_OVERNIGHT'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE' }.merge(baseline_testcase_options))
  end
  
  def test_de_002
    setup_user('US')
    
    customer_transaction_id = 'DE-002'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'ALAMEDA',
                             :province => 'CA',
                             :postal_code => '94501',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Date.parse('Saturday')
    
    baseline_testcase_options = {
      :saturday_pickup => true
    }
    
    height, width, length = 0,0,0
    insured_value = 499.00
    weight = 4
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_PAK'
    service_type = 'FEDEX_EXPRESS_SAVER'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_de_003
    setup_user('US')
    
    customer_transaction_id = 'DE-003'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'COLLIERVILLE',
                             :province => 'TN',
                             :postal_code => '38017',
                             :country => 'US',
                             :address_type => nil)
    
    ship_date = Time.now
    
    baseline_testcase_options = {
    }
    
    height, width, length = 0,0,0
    insured_value = 220.00
    weight = 2
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_BOX'
    service_type = 'FIRST_OVERNIGHT'
    signature_service = 'INDIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_de_004
    setup_user('US')
    
    customer_transaction_id = 'DE-004'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'NORTH LAS VEGAS',
                             :province => 'NV',
                             :postal_code => '89030',
                             :country => 'US',
                             # :address_type => nil)
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
    }
    
    height, width, length = 0,0,0
    insured_value = 550.00
    weight = 3
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_TUBE'
    service_type = 'FEDEX_2_DAY'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_de_005
    setup_user('US')
    
    customer_transaction_id = 'DE-005'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'ALAMEDA',
                             :province => 'CA',
                             :postal_code => '94501',
                             :country => 'US',
                             # :address_type => nil)
                             :address_type => 'residential')
    
    ship_date = Date.parse('Friday')
    # ship_date = Time.now
    
    baseline_testcase_options = {
      :saturday_delivery => false#true
    }
    
    height, width, length = 0,0,0
    insured_value = 220.00
    weight = 1.0 
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_ENVELOPE'
    service_type = 'PRIORITY_OVERNIGHT'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_de_001
    setup_user('US')
    
    customer_transaction_id = 'NRF-DE-001'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'COLLIERVILLE',
                             :province => 'TN',
                             :postal_code => '38017',
                             :country => 'US',
                             # :address_type => nil)
                             :address_type => 'residential')
    
    # ship_date = Date.parse('Friday')
    ship_date = Time.now
    
    baseline_testcase_options = {
      # :saturday_delivery => true
    }
    
    height, width, length = 2,4,7
    insured_value = 550.00
    weight = 25
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'PRIORITY_OVERNIGHT'
    signature_service = 'ADULT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_de_002
    setup_user('US')
    
    customer_transaction_id = 'NRF-DE-002'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => ' NORTH LAS VEGAS',
                             :province => 'NV',
                             :postal_code => '89030',
                             :country => 'US',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    # ship_date = Date.parse('Friday')
    ship_date = Time.now
    
    baseline_testcase_options = {
      :dangerous_goods => {:accessibility => 'INACCESSIBLE', :cargo_aircraft_only => true, :dot_proper_shipping_name => 'Infectious substance, affecting humans (solid)', :dot_id_number => '2814', :quantity => '1', :packing_group => 'Bottle', :units => 'mL', :twenty_four_hour_emergency_response_contact_number => '8005787787', :twenty_four_hour_emergency_response_contact_name => 'Lab Engineer', :dot_hazard_class_or_division => '6.2'}
    }
    
    height, width, length = 2,4,7
    insured_value = 550.00
    weight = 40
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_2_DAY'
    signature_service = 'ADULT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_de_003
    setup_user('US')
    
    customer_transaction_id = 'NRF-DE-003'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => ' ALAMEDA',
                             :province => 'CA',
                             :postal_code => '94501',
                             :country => 'US',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    # ship_date = Date.parse('Friday')
    ship_date = Time.now
    
    baseline_testcase_options = {
      :dangerous_goods => {:accessibility => 'ACCESSIBLE', :cargo_aircraft_only => true, :dot_id_number => '3327', :quantity => '2', :packing_group => 'Drum', :units => 'Kg', :twenty_four_hour_emergency_response_contact_number => '8889950495', :twenty_four_hour_emergency_response_contact_name => 'Director'}
    }
    
    height, width, length = 2,4,7
    insured_value = 210.00
    weight = 500
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_1_DAY_FREIGHT'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_de_004
    setup_user('US')
    
    customer_transaction_id = 'NRF-DE-004'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'COLLIERVILLE',
                             :province => 'TN',
                             :postal_code => '38017',
                             :country => 'US',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Date.parse('Thursday')
    # ship_date = Time.now
    
    baseline_testcase_options = {
      # :dry_ice => {:weight_value => '5', :weight_units => 'KG'}
    }
    
    height, width, length = 2,4,7
    insured_value = 250.00
    weight = 200
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_2_DAY_FREIGHT'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD', :dry_ice => Quantified::Mass.new(5, :kilograms))]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_de_005
    setup_user('US')
    
    customer_transaction_id = 'NRF-DE-005'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '121 FedEx',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => 'FEDEX PARKWAY',
                             :city => 'NORTH LAS VEGAS',
                             :province => 'NV',
                             :postal_code => '89030',
                             :country => 'US',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    # ship_date = Date.parse('Thursday')
    ship_date = Time.now
    
    baseline_testcase_options = {
      :hold_at_location => Location.new(:address1 => '8455 PARDEE DR', :city => 'Oakland', :province => 'CA', :postal_code => '94621', :phone => '90126333035')
    }
    
    height, width, length = 2,4,7
    insured_value = 360.00
    weight = 200
    customs_value = nil
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_3_DAY_FREIGHT'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_001
    setup_user('US')
    
    customer_transaction_id = 'IE-001'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'Calgary',
                             :province => 'AB',
                             :postal_code => 'T2E7R6',
                             :country => 'CA',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Date.parse('Friday')
    # ship_date = Time.now
    
    baseline_testcase_options = {
      :saturday_delivery => true
    }
    
    height, width, length = 2,4,7
    insured_value = 220
    weight = 4
    customs_value = 500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_PRIORITY'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_002
    setup_user('US')
    
    customer_transaction_id = 'IE-002'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'Koeln',
                             :province => 'CO',
                             :postal_code => '51149',
                             :country => 'DE',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Date.parse('Saturday')
    
    baseline_testcase_options = {
      :saturday_pickup => true
    }
    
    height, width, length = 2,4,7
    insured_value = 100
    weight = 6
    customs_value = 500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_PAK'
    service_type = 'INTERNATIONAL_ECONOMY'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_003
    setup_user('US')
    
    customer_transaction_id = 'IE-003'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
    }
    
    height, width, length = 2,4,7
    insured_value = 100
    weight = 4
    customs_value = 100
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_BOX'
    service_type = 'INTERNATIONAL_FIRST'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_004
    setup_user('US')
    
    customer_transaction_id = 'IE-004'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'Koeln',
                             :province => 'CO',
                             :postal_code => '51149',
                             :country => 'DE',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Date.parse('Saturday')
    
    baseline_testcase_options = {
      :saturday_pickup => true
    }
    
    height, width, length = 2,4,7
    insured_value = 440
    weight = 6
    customs_value = 500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_TUBE'
    service_type = 'INTERNATIONAL_PRIORITY'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_005
    setup_user('US')
    
    customer_transaction_id = 'IE-005'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
    
    ship_date = Date.parse('Saturday')
    
    baseline_testcase_options = {
      :saturday_pickup => true
    }
    
    height, width, length = 2,4,7
    insured_value = 100
    weight = 1.0
    customs_value = 100
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'FEDEX_ENVELOPE'
    service_type = 'INTERNATIONAL_ECONOMY'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_nrf_001
    setup_user('US')
    
    customer_transaction_id = 'IE-NRF-001'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'PARIS',
                             :province => 'FR',
                             :postal_code => '75001',
                             :country => 'FR',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      # :saturday_pickup => true
      :hold_at_location => Location.new(:postal_code => '25')
    }
    
    height, width, length = 40,40,40
    insured_value = 1250
    weight = 250
    customs_value = 1500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_PRIORITY_FREIGHT'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_nrf_002
    setup_user('US')
    
    customer_transaction_id = 'IE-NRF-002'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'MELSBROEK',
                             :province => 'BE',
                             :postal_code => '1820',
                             :country => 'BE',
                             :address_type => nil)
                             # :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :dangerous_goods => {:accessibility => 'ACCESSIBLE', :dot_proper_shipping_name => 'Methyl trichloroacetate', :dot_id_number => '2533', :quantity => '1', :packing_group => 'Drum', :units => 'L', :twenty_four_hour_emergency_response_contact_number => '8005557865', :twenty_four_hour_emergency_response_contact_name => 'Director', :cargo_aircraft_only => true, :dot_hazard_class_or_division => '6.1'}
    }
    
    height, width, length = 5,5,5
    insured_value = 1500
    weight = 68
    customs_value = 12500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_PRIORITY'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_nrf_003
    setup_user('US')
    
    customer_transaction_id = 'IE-NRF-003'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'SINGAPORE',
                             :province => 'SG',
                             :postal_code => '118478',
                             :country => 'SG',
                             :address_type => nil)
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :dangerous_goods => {:accessibility => 'INACCESSIBLE', :dot_proper_shipping_name => 'Methyl trichloroacetate', :dot_id_number => '2533', :quantity => '1', :packing_group => 'Drum', :units => 'L', :twenty_four_hour_emergency_response_contact_number => '8005557865', :twenty_four_hour_emergency_response_contact_name => 'Director', :cargo_aircraft_only => true, :dot_hazard_class_or_division => '6.1'}
    }
    
    height, width, length = 25,25,25
    insured_value = 300
    weight = 70
    customs_value = 25000
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_PRIORITY'
   signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_nrf_004
    setup_user('US')
    
    customer_transaction_id = 'IE-NRF-004'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'Calgary',
                             :province => 'AB',
                             :postal_code => 'T2E7R6',
                             :country => 'CA',
                             :address_type => nil)
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :dry_ice => {:quantity => 1, :weight_units => 'KG', :weight_value => 9.1}
    }
    
    height, width, length = 5,5,5
    insured_value = 440
    weight = 20
    customs_value = 500
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_PRIORITY'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_ie_nrf_005
    setup_user('US')
    
    customer_transaction_id = 'IE-NRF-005'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '500 THORNHILL LN',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex Prkwy',
                             :city => 'NEW DELHI',
                             :province => 'IN',
                             :postal_code => '110001',
                             :country => 'IN',
                             :address_type => nil)
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :hold_at_location => Location.new(:phone => '901-263-3035', :address1 => '102 FedEx', :city => 'MUMBAI', :province => 'IN', :postal_code => '411027')
    }
    
    height, width, length = 40,40,40
    insured_value = 100
    weight = 60
    customs_value = 100
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'INTERNATIONAL_ECONOMY_FREIGHT'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXE', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_dom_gnd_001
    setup_user('US')
    
    customer_transaction_id = 'DOM-GND-001'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1751 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'COLLIERVILLE',
                             :province => 'TN',
                             :postal_code => '38017',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :cod => {:type => 'CASH', :amount => 250, :currency => 'USD'}
    }
    
    height, width, length = 2,4,7
    insured_value = 250
    weight = 100
    customs_value = 100
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_GROUND'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_int_gnd_002
    setup_user('US')
    
    customer_transaction_id = 'INT-GND-002'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1751 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'Mississauga',
                             :province => 'ON',
                             :postal_code => 'L4W5K6',
                             :country => 'CA',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    baseline_testcase_options = {
      :cod => {:type => 'ANY', :amount => 5000, :currency => 'CAD'}
    }
    
    height, width, length = 2,4,7
    insured_value = 250
    weight = 100
    customs_value = 250.00
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_GROUND'
    signature_service = 'NO_SIGNATURE_REQUIRED'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_hd_003
    setup_user('US')
    
    customer_transaction_id = 'HD-003'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1751 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'Stoystown',
                             :province => 'PA',
                             :postal_code => '15563',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Date.today
    certain_ship_date = Date.new(2010,12,28)
    
    baseline_testcase_options = {
      :home_delivery_premium => {:type => 'DATE_CERTAIN', :date => certain_ship_date, :phone => '9012633335'}
    }
    
    height, width, length = 2,4,7
    insured_value = 100
    weight = 28
    customs_value = nil
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'GROUND_HOME_DELIVERY'
    signature_service = 'ADULT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_hd_004
    setup_user('US')
    
    customer_transaction_id = 'HD-004'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1751 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'Memphis',
                             :province => 'TN',
                             :postal_code => '38125',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    one_week_in_seconds = 7*60*60*24
    baseline_testcase_options = {
      :home_delivery_premium => {:type => 'APPOINTMENT', :date => ship_date, :phone => '9012633335'}
    }
    
    height, width, length = 2,4,7
    insured_value = 600
    weight = 28
    customs_value = nil
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'GROUND_HOME_DELIVERY'
    signature_service = nil
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_hd_005
    setup_user('US')
    
    customer_transaction_id = 'HD-005'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1752 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'Fort Lauderdale',
                             :province => 'FL',
                             :postal_code => '33304',
                             :country => 'US',
                             :address_type => 'residential')
    
    ship_date = Time.now
    
    one_week_in_seconds = 7*60*60*24
    baseline_testcase_options = {
      :home_delivery_premium => {:type => 'EVENING', :date => ship_date, :phone => '9012633335'}
    }
    
    height, width, length = 2,4,7
    insured_value = 200
    weight = 28
    customs_value = nil
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'GROUND_HOME_DELIVERY'
    signature_service = 'ADULT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
  end
  
  def test_nrf_gnd_006
    setup_user('US')
    
    customer_transaction_id = 'NRF-GND-006'
    
    shipper = Location.new(:person_name => 'SHIPPER',
                           :address1 => '1752 THOMPSON ST',
                           :city => 'AURORA',
                           :province => 'OH',
                           :postal_code => '44202',
                           :country => 'US')
    
    recipient = Location.new(:person_name => 'RECIPIENT',
                             :address1 => '80 Fedex PRKWY',
                             :city => 'New York',
                             :province => 'NY',
                             :postal_code => '10001',
                             :country => 'US',
                             :address_type => nil)
    
    ship_date = Time.now
    
    one_week_in_seconds = 7*60*60*24
    baseline_testcase_options = {
      :dangerous_goods => {:cargo_aircraft_only => true, :dot_proper_shipping_name => 'Methyl trichloroacetate', :dot_id_number => '2814.00', :quantity => 1, :packing_group => 'D', :units => 'L', :twenty_four_hour_emergency_response_contact_number => '9012633335', :twenty_four_hour_emergency_response_contact_name => 'ANDY', :dot_hazard_class_or_division => '6.2'},
      :non_standard_container => true
    }
    
    height, width, length = 10,15,61
    insured_value = 250
    weight = 50
    customs_value = nil
    shipper.instance_variable_set(:@phone, '9012633035')
    
    dropoff_type = 'REGULAR_PICKUP'
    packaging_type = 'YOUR_PACKAGING'
    service_type = 'FEDEX_GROUND'
    signature_service = 'DIRECT'
    
    # Assumes 16 ounce to the pound
    packages = [Package.new(weight * 16, [height, width, length], :units => :imperial, :value => insured_value, :currency => 'USD')]
    
    response = @carrier.find_rates(shipper, recipient, packages, {:customer_transaction_id => customer_transaction_id, :shipping_charges => {:payment_type => 'SENDER', :payor_account_number => @carrier.user_credentials[:account_number], :payor_country_code => 'US'}, :ship_date => ship_date, :customs_value => customs_value, :dropoff_type => dropoff_type, :packaging_type => packaging_type, :signature_option => signature_service, :rate_request_types => 'LIST', :carrier_code => 'FDXG', :service_type => service_type}.merge(baseline_testcase_options))
    File.open("/Users/jesse/work/FedEx\ CSP\ for\ ActiveShipping/Test\ Transactions/Baseline cases/#{file_name}.xml", 'w') do |f|
      f.puts xml_tidy(response.request)
      f.puts "<!-- -->"
      f.puts
      f.puts xml_tidy(response.xml)
    end
  end
  
  def xml_tidy(s)
    result = IO.popen("XMLLINT_INDENT='  ' xmllint --format -", 'r+') do |pipe|
      pipe << s
      pipe.close_write
      pipe.read
    end
  end
end
