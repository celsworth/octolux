#! /usr/bin/env ruby
# frozen_string_literal: true

# dirt simple test script to connect to the inverter and dump debugging information
# about any packets we receive.

require_relative '../boot'

require 'socket'
require 'lxp/packet'

s = TCPSocket.new(CONFIG['lxp']['host'], CONFIG['lxp']['port'])

begin
  loop do
    input = s.recvfrom(2048)[0]
    puts "#{Time.now} :: PACKET: #{input.unpack('C*')}"

    parser = LXP::Packet::Parser.new(input)
    p parser.parse
  end
ensure
  s.close
end
