# frozen_string_literal: true

require 'lxp/packet'

class LuxController
  SocketError = Class.new(StandardError)

  def initialize(host:, port:, serial:, datalog:)
    @host = host
    @port = port
    # these can be numeric, but we want them as strings to put into data packets
    @serial = serial.to_s
    @datalog = datalog.to_s
  end

  def close
    @socket&.close
    @socket = nil
  end

  def read_input(num)
    LOGGER.debug "read_input(#{num})"

    type = case num
           when 1 then LXP::Packet::ReadInput1
           when 2 then LXP::Packet::ReadInput2
           when 3 then LXP::Packet::ReadInput3
           end

    pkt = packet(type: type)
    socket.write(pkt)
    read_reply(pkt)
  end

  def read_hold(register)
    read_register(register)
  end

  def charge(enable)
    LOGGER.debug "charge(#{enable})"
    update_register(21, LXP::Packet::RegisterBits::AC_CHARGE_ENABLE, enable)
  end

  def discharge(enable)
    LOGGER.debug "discharge(#{enable})"
    update_register(
      21, LXP::Packet::RegisterBits::FORCED_DISCHARGE_ENABLE, enable
    )
  end

  # Untested - get current charge power %
  def charge_pct
    read_register(LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD)
  end

  # Untested - set current charge power %
  def charge_pct=(pct)
    set_register(LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD, pct)
  end

  # Get current discharge power %
  def discharge_pct
    read_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD)
  end

  # Set current discharge power %
  def discharge_pct=(pct)
    set_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD, pct)
  end

  # Untested - get current charge amount %
  def charge_amount_pct
    read_register(LXP::Packet::Registers::AC_CHARGE_SOC_LIMIT)
  end

  # Untested - set current charge amount %
  def charge_amount_pct=(pct)
    set_register(LXP::Packet::Registers::AC_CHARGE_SOC_LIMIT, pct)
  end

  private

  # Update a given register (21 for AC CHARGE/DISCHARGE) with the given bit
  # (AC_CHARGE_ENABLE or FORCED_DISCHARGE_ENABLE) setting it on or off.
  #
  # Returns true if the bit was already as requested, or updated.
  #
  def update_register(register, bit, enable)
    LOGGER.debug "update_register(#{register}, #{bit}, #{enable})"

    old_val = read_register(register)
    enabled = (old_val & bit) == bit
    if enable == enabled
      LOGGER.debug "update_register(#{register}) => no action required"
      return true
    end

    new_val = enable ? old_val | bit : old_val & ~bit
    ret_val = set_register(register, new_val)

    new_val == ret_val
  end

  def read_register(register)
    LOGGER.debug "read_register(#{register})"
    pkt = packet(type: LXP::Packet::ReadHold, register: register)
    socket.write(pkt)
    r = read_reply(pkt)

    LOGGER.debug "read_register(#{register}) => #{r.value}"

    r.value
  end

  def set_register(register, val)
    LOGGER.debug "set_register(#{register}, #{val})"

    pkt = packet(type: LXP::Packet::WriteSingle, register: register)
    pkt.value = val

    socket.write(pkt)
    r = read_reply(pkt)

    LOGGER.debug "set_register(#{register}) => #{r.value}"

    r.value
  end

  def socket
    @socket ||= LuxSocket.new(host: @host, port: @port)
  end

  def packet(type:, register: nil)
    type.new.tap do |pkt|
      pkt.register = register if register
      pkt.datalog_serial = @datalog
      pkt.inverter_serial = @serial
    end
  end

  def read_reply(pkt)
    unless (r = socket.read_reply(pkt))
      LOGGER.fatal 'invalid/no reply from inverter'
      raise SocketError
    end

    r
  end
end
