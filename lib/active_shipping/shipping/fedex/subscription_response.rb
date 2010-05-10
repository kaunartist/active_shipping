module ActiveMerchant #:nodoc:
  module Shipping
    class FedEx < Carrier
      class SubscriptionResponse < Response
        attr_reader :meter_number
      
        def initialize(success, message, params = {}, options = {})
          @meter_number = options[:meter_number]
          super
        end
      end
    end    
  end
end