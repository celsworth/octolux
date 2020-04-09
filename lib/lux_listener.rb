# frozen_string_literal: true

require 'lxp/packet'

# This starts in a thread and watches for incoming traffic from the inverter.
#
class LuxListener
  class << self
    def run
      loop do
        socket = LuxSocket.new(host: CONFIG['lxp']['host'], port: CONFIG['lxp']['port'])
        listen(socket)
      rescue StandardError => e
        LOGGER.error "Socket Error: #{e}"
        LOGGER.info 'Reconnecting in 5 seconds'
        sleep 5
      end
    end

    # A Hash containing merged input data, as parsed by LXP::Packet::ReadInput
    def inputs
      @inputs ||= {}
    end

    # A Hash containing register information we've seen from LXP::Packet::ReadHold packets
    def registers
      @registers ||= {}
    end

    def pv_power
      inputs[:p_pv]
    end

    # Return charge power, or if discharging, discharge power (which will be negative)
    def charge_power
      inputs[:p_charge] || (-inputs[:p_discharge] if inputs[:p_discharge])
    end

    private

    def listen(socket)
      loop do
        next unless (pkt = socket.read_packet)

        @last_packet = Time.now
        process_input(pkt) if pkt.is_a?(LXP::Packet::ReadInput)
        process_read_hold(pkt) if pkt.is_a?(LXP::Packet::ReadHold)
        process_write_single(pkt) if pkt.is_a?(LXP::Packet::WriteSingle)
      end
    ensure
      socket.close
    end

    def process_input(pkt)
      inputs.merge!(pkt.to_h)

      n = case pkt
          when LXP::Packet::ReadInput1 then 1
          when LXP::Packet::ReadInput2 then 2
          when LXP::Packet::ReadInput3 then 3
          end

      MQ.publish("octolux/inputs/#{n}", pkt.to_h)
    end

    def process_read_hold(pkt)
      pkt.to_h.each do |register, value|
        registers[register] = value
        MQ.publish("octolux/hold/#{register}", value)
      end
    end

    def process_write_single(pkt)
      registers[pkt.register] = pkt.value
      MQ.publish("octolux/hold/#{pkt.register}", pkt.value)
    end
  end
end
