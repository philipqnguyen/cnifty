lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'cnifty'

tempdir = File.expand_path 'temp', __dir__

payment_address = Cnifty::PaymentAddress.new
File.write "#{tempdir}/payment.skey", payment_address.skey
File.write "#{tempdir}/payment.vkey", payment_address.vkey
File.write "#{tempdir}/payment.address", payment_address.to_s
