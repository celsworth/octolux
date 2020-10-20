# frozen_string_literal: true

# octopus contains tariff price data
#   octopus.price is current cost in pence
#   octopus.prices is a hash of all known price data, keyed by time
LOGGER.info "Current Octopus Unit Price: #{octopus.price}p"

# $lc is LuxController. This talks directly to the inverter and can do things
# like enabling/disabling AC charge and setting charge power rates.
# LOGGER.info "Charge Power = #{lc-mast.charge_pct}%"
# LOGGER.info "Charge Power = #{lc-slave.charge_pct}%"

# $ls is LuxStatus. This is gleaned from the optional server.rb since the
# data in it is only sent by the inverter every 2 minutes.
#   .inputs is a hash of input data. this will be empty if we cannot fetch the status
# LOGGER.info "Battery SOC = #{ls.data['soc']}%" if ls.inputs['soc']

begin
  # if the current price is 5p or lower, enable AC charge
  charge = octopus.price <= 5

  unless lc-mast.charge(charge)
    LOGGER.error 'Failed to update master inverter status :-('
    exit 255
  end

  unless lc-slave.charge(charge)
    LOGGER.error 'Failed to update slave inverter status :-('
    exit 255
  end
rescue StandardError => e
  LOGGER.error "Error: #{e}"
  exit 255
end
