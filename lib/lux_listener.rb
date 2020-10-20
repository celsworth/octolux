# frozen_string_literal: true

require 'lxp/packet'

# This starts in a thread and watches for incoming traffic from the inverter.
#
class LuxListener
  class << self
    def run(host:, port:, slave:)
      LOGGER.info "LuxListener - host #{host} port #{port} slave #{slave}"
      @slave = slave

      loop do
        socket = LuxSocket.new(host: host, port: port)
        if @slave == 0
          LOGGER.info("Created new Master LuxListener")          
        else
          LOGGER.info("Created new Slave LuxListener")
        end

        listen(socket, slave)
      rescue StandardError => e
        if @slave == 0
          LOGGER.error "Socket Master Error: #{e}"
        else
          LOGGER.error "Socket Slave Error: #{e}"
        end
        LOGGER.debug e.backtrace.join("\n")
        if @slave == 0
          LOGGER.info 'Reconnecting to Master in 5 seconds'
        else
          LOGGER.info 'Reconnecting to Slave in 5 seconds'
        end
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

    private

    def listen(socket, slave)
      loop do
        next unless (pkt = socket.read_packet)

        @last_packet = Time.now
        process_input(pkt, slave) if pkt.is_a?(LXP::Packet::ReadInput)
        process_read_hold(pkt, slave) if pkt.is_a?(LXP::Packet::ReadHold)
        process_write_single(pkt, slave) if pkt.is_a?(LXP::Packet::WriteSingle)
      end
    ensure
      socket.close
    end

    def process_input(pkt, slave)
      inputs.merge!(pkt.to_h)

      n = case pkt
          when LXP::Packet::ReadInput1 then 1
          when LXP::Packet::ReadInput2 then 2
          when LXP::Packet::ReadInput3 then 3
          end

      # Not very neat... but it allows us to see both inverters seperatly.
      if slave == 0
        MQ.publish("octolux/masterinputs/#{n}", pkt.to_h, slave)
      else
        MQ.publish("octolux/slaveinputs/#{n}", pkt.to_h, slave)
      end
    end

    def process_read_hold(pkt, slave)
      pkt.to_h.each do |register, value|
        registers[register] = value
        if slave == 0
          MQ.publish("octolux/masterhold/#{register}", value, slave)
        else
          MQ.publish("octolux/slavehold/#{register}", value, slave)
        end
      end
    end

    def process_write_single(pkt, slave)
      registers[pkt.register] = pkt.value
      if slave == 0
        MQ.publish("octolux/masterhold/#{pkt.register}", pkt.value, slave)
      else
        MQ.publish("octolux/slavehold/#{pkt.register}", pkt.value, slave)
      end
    end
  end #class << self
end #class LuxListener
