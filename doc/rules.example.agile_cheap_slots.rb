# frozen_string_literal: true

LOGGER.info "Current Price = #{octopus.price}p"

required_soc = CONFIG['rules']['required_soc'].to_i

if (soc = ls.inputs['soc'])
  LOGGER.info "SOC = #{soc}% / #{required_soc}%"
else
  LOGGER.warn "Can't get SOC % from server.rb, assuming 10%"
  soc = 10
end

slots = octopus.prices.sort_by { |_k, v| v }

now = Time.at(1800 * (Time.now.to_i / 1800))

f = Pathname.new('cheap_slot_data.json')
data = f.readable? ? JSON.parse(f.read) : {}

# charge_slots are worked out each evening after 6pm, when we have new Octopus price data.
evening = now.hour >= 18
stale = data['updated_at'].nil? || Time.now - Time.parse(data['updated_at']) > (23 * 60 * 60)
have_prices = octopus.prices.count > 20
if (evening || stale) && have_prices
  battery_count = CONFIG['lxp']['batteries'].to_i
  charge_rate = [3, battery_count].min

  system_size = 2.4 * battery_count # kWh per battery
  # TODO: bias this based on solcast?
  charge_size = system_size * ((required_soc - soc) / 100.0)
  charge_size = 0 if charge_size.negative?
  hours_required = charge_size / charge_rate.to_f
  slots_required = (hours_required * 2).ceil # half-hourly Agile periods

  LOGGER.info "charge_size = #{charge_size.round(2)} kWh, hours = #{hours_required.round(2)}"

  # the cheapest slots are used to charge up to required_soc. these are restricted to 8pm-8am
  # so we don't end up trying to charge during the day in normal circumstances.
  night_slots = slots.select do |time, _price|
    (now.hour > 8 && now.day == time.day && time.hour >= 20) || time.hour <= 8
  end
  charge_slots = night_slots.shift(slots_required).to_h

  data = { 'updated_at' => Time.now, 'charge_slots' => charge_slots }

  f.write(JSON.generate(data))
else
  charge_slots = data['charge_slots'] || {}

  # convert keys back to Time objects
  charge_slots = charge_slots.map { |time, price| [Time.parse(time), price] }.to_h
end

# merge in any slots with a price cheaper than cheap_charge from config
cheap_charge = CONFIG['rules']['cheap_charge'].to_f
cheap_slots = octopus.prices.select { |_time, price| price < cheap_charge }
charge_slots.merge!(cheap_slots)

charge_slots.sort.each { |time, price| LOGGER.info "Charge: #{time} @ #{price}p" }

max_charge_price = charge_slots[charge_slots.keys.last] || cheap_charge
# discharge_slots depends how much SOC we have. The more SOC, we more generous we can be
# with discharging. The lower the SOC, the more we want to save that charge for higher prices.
multiplier = if soc < 30 then 1.6
             elsif soc < 40 then 1.5
             elsif soc < 50 then 1.4
             elsif soc < 60 then 1.3
             elsif soc < 80 then 1.2
             else
               1.1
             end
min_discharge_price = max_charge_price * multiplier
min_discharge_price = [min_discharge_price, CONFIG['rules']['min_discharge'].to_f].max.round(4)
discharge_slots = slots.delete_if { |_k, v| v <= min_discharge_price }.to_h
# discharge_slots.sort.each { |time, price| LOGGER.info "Discharge: #{time} @ #{price}p" }

# this is just used for informational logging. Need to convert back to Time if loaded from JSON.
t = (charge_slots.keys + discharge_slots.keys).map { |n| n.is_a?(Time) ? n : Time.parse(n) }
idle = octopus.prices.reject { |k, _v| t.include?(k) }
idle.sort.each { |time, price| LOGGER.info "Idle: #{time} @ #{price}p" }

# enable ac_charge/discharge if any of the keys match the current half-hour period
ac_charge = charge_slots.any? { |time, _price| time == now }
discharge = discharge_slots.any? { |time, _price| time == now }

emergency_soc = CONFIG['rules']['emergency_soc'] || 50
# if a peak period is approaching and SOC is low, start emergency charge
if soc < emergency_soc.to_i && octopus.prices.values.take(4).max > 15 && octopus.price < 15
  LOGGER.warn 'Peak approaching, emergency charging'
  ac_charge = true
end

LOGGER.info "ac_charge = #{ac_charge} ; discharge = #{discharge} (> #{min_discharge_price}p)"

discharge_pct = discharge ? 100 : 0
r-mast = (lc-mast.discharge_pct = discharge_pct)
exit 255 unless r-mast == discharge_pct

exit 255 unless lc-mast.charge(ac_charge)
