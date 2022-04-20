lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'cnifty'

tempdir = File.expand_path 'temp', __dir__

payment_addr = File.read "#{tempdir}/payment.address"
payment_skey = File.read "#{tempdir}/payment.skey"
payment_vkey = File.read "#{tempdir}/payment.vkey"

payment_address = Cnifty::PaymentAddress.new address: payment_addr,
                                             skey: payment_skey,
                                             vkey: payment_vkey

destination_address = Cnifty::PaymentAddress.new address: 'addr_test1qpy4vj3tstuk2vzm9q8036u2svwgvtu8de6pv8r7rtvqfz5rxnlrdkz20h0dns95m8qu5yg0d7g36h4cs7ragv8jtkqqqtmrgm'

policy = Cnifty::Policy.new


transaction = Cnifty::Transaction.new destination_address: destination_address,
                                      payment_address: payment_address,
                                      ada: 2_000_000

puts transaction.submit
