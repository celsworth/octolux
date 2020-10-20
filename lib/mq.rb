# frozen_string_literal: true

require 'mqtt/sub_handler'

class MQ
  class << self
    def run
      sub.subscribe_to 'octolux/cmd/read_hold', &method(:read_hold_cb)
      sub.subscribe_to 'octolux/cmd/read_input', &method(:read_input_cb)

      sub.subscribe_to 'octolux/cmd/ac_charge', &method(:ac_charge_cb)
      sub.subscribe_to 'octolux/cmd/forced_discharge', &method(:forced_discharge_cb)
      sub.subscribe_to 'octolux/cmd/charge_pct', &method(:charge_pct_cb)
      sub.subscribe_to 'octolux/cmd/discharge_pct', &method(:discharge_pct_cb)

      Thread.stop # sleep forever
    end

    def publish(topic, message, slave)
      sub.publish_to(topic, message) if uri
      @slave = slave
    end

    private

    def read_hold_cb(data, *)
      LOGGER.info "MQ cmd/read_hold => #{data}"
      if @slave == 0
        lux_controller.read_hold(data.to_i)
        lux_controller.close
      else
        lux_controllerslave.read_hold(data.to_i)
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/read_hold', 'OK')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/read_hold', 'FAIL')
    end

    def read_input_cb(data, *)
      LOGGER.info "MQ cmd/read_input => #{data}"
      if @slave == 0
        lux_controller.read_input(data.to_i)
        lux_controller.close
      else
        lux_controllerslave.read_input(data.to_i)
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/read_input', 'OK')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/read_input', 'FAIL')
    end

    def ac_charge_cb(data, *)
      LOGGER.info "MQ cmd/ac_charge => #{data}"
      if @slave == 0
        r = lux_controller.charge(bool(data))
        lux_controller.close
      else
        r = lux_controllerslave.charge(bool(data))
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/ac_charge', r ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/ac_charge', 'FAIL')
    end

    def forced_discharge_cb(data, *)
      LOGGER.info "MQ cmd/forced_discharge => #{data}"
      if @slave == 0
        r = lux_controller.discharge(bool(data))
        lux_controller.close
      else
        r = lux_controllerslave.discharge(bool(data))
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/forced_discharge', r ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/forced_discharge', 'FAIL')
    end

    def charge_pct_cb(data, *)
      LOGGER.info "MQ cmd/charge_pct => #{data}"
      if @slave == 0
        r = (lux_controller.charge_pct = data.to_i)
        lux_controller.close
      else
        r = (lux_controllerslave.charge_pct = data.to_i)
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/charge_pct', r == data.to_i ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/charge_pct', 'FAIL')
    end

    def discharge_pct_cb(data, *)
      LOGGER.info "MQ cmd/discharge_pct => #{data}"
      if @slave == 0
        r = (lux_controller.discharge_pct = data.to_i)
        lux_controller.close
      else
        r = (lux_controllerslave.discharge_pct = data.to_i)
        lux_controllerslave.close
      end
      sub.publish_to('octolux/result/discharge_pct', r == data.to_i ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/discharge_pct', 'FAIL')
    end

    def uri
      CONFIG['mqtt']['uri']
    end

    def sub
      @sub ||= MQTT::SubHandler.new(uri)
    end

    def lux_controller
      # FIXME: duplicated in octolux.rb, could move to boot.rb?
      @lux_controller ||= LuxController.new(host: CONFIG['lxp']['host'],
                                            port: CONFIG['lxp']['port'],
                                            serial: CONFIG['lxp']['serial'],
                                            datalog: CONFIG['lxp']['datalog'])

      @lux_controllerslave ||= LuxController.new(host: CONFIG['lxp']['host_slave'],
                                              port: CONFIG['lxp']['port_slave'],
                                              serial: CONFIG['lxp']['serial_slave'],
                                              datalog: CONFIG['lxp']['datalog_slave'])
        end

    def bool(input)
      case input
      when true, 1, /\A(?:1|t(?:rue)?|y(?:es)?|on)\z/i then true
      else false
      end
    end
  end
end
