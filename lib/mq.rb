# frozen_string_literal: true

require 'mqtt/sub_handler'

class MQ
  class << self
    def run
      sub.subscribe_to 'octolux/cmd/read_hold', &method(:read_hold_cb)
      sub.subscribe_to 'octolux/cmd/read_input', &method(:read_input_cb)

      sub.subscribe_to 'octolux/cmd/ac_charge', &method(:ac_charge_cb)
      sub.subscribe_to 'octolux/cmd/ac_charge_priority', &method(:charge_priority_cb)
      sub.subscribe_to 'octolux/cmd/forced_discharge', &method(:forced_discharge_cb)
      sub.subscribe_to 'octolux/cmd/charge_pct', &method(:charge_pct_cb)
      sub.subscribe_to 'octolux/cmd/discharge_pct', &method(:discharge_pct_cb)

      sub.subscribe_to 'octolux/cmd/charge_amount_pct', &method(:charge_amount_pct_cb)

      Thread.stop # sleep forever
    end

    def publish(topic, message)
      sub.publish_to(topic, message) if uri
    end

    private

    def read_hold_cb(data, *)
      LOGGER.info "MQ cmd/read_hold => #{data}"
      lux_controller.read_hold(data.to_i)
      lux_controller.close
      sub.publish_to('octolux/result/read_hold', 'OK')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/read_hold', 'FAIL')
    end

    def read_input_cb(data, *)
      LOGGER.info "MQ cmd/read_input => #{data}"
      lux_controller.read_input(data.to_i)
      lux_controller.close
      sub.publish_to('octolux/result/read_input', 'OK')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/read_input', 'FAIL')
    end

    def ac_charge_cb(data, *)
      LOGGER.info "MQ cmd/ac_charge => #{data}"
      r = lux_controller.charge(bool(data))
      lux_controller.close
      sub.publish_to('octolux/result/ac_charge', r ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/ac_charge', 'FAIL')
    end

    def charge_priority_cb(data, *)
      LOGGER.info "MQ cmd/charge_priority => #{data}"
      r = lux_controller.charge_priority(bool(data))
      lux_controller.close
      sub.publish_to('octolux/result/charge_priority', r ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/charge_priority', 'FAIL')
    end

    def forced_discharge_cb(data, *)
      LOGGER.info "MQ cmd/forced_discharge => #{data}"
      r = lux_controller.discharge(bool(data))
      lux_controller.close
      sub.publish_to('octolux/result/forced_discharge', r ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/forced_discharge', 'FAIL')
    end

    def charge_pct_cb(data, *)
      LOGGER.info "MQ cmd/charge_pct => #{data}"
      r = (lux_controller.charge_pct = data.to_i)
      lux_controller.close
      sub.publish_to('octolux/result/charge_pct', r == data.to_i ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/charge_pct', 'FAIL')
    end

    def discharge_pct_cb(data, *)
      LOGGER.info "MQ cmd/discharge_pct => #{data}"
      r = (lux_controller.discharge_pct = data.to_i)
      lux_controller.close
      sub.publish_to('octolux/result/discharge_pct', r == data.to_i ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/discharge_pct', 'FAIL')
    end

    def charge_amount_pct_cb(data, *)
      LOGGER.info "MQ cmd/charge_amount_pct => #{data}"
      r = (lux_controller.charge_amount_pct = data.to_i)
      lux_controller.close
      sub.publish_to('octolux/result/charge_amount_pct', r == data.to_i ? 'OK' : 'FAIL')
    rescue LuxController::SocketError
      sub.publish_to('octolux/result/charge_amount_pct', 'FAIL')
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
    end

    def bool(input)
      case input
      when true, 1, /\A(?:1|t(?:rue)?|y(?:es)?|on)\z/i then true
      else false
      end
    end
  end
end
