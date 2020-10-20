#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'rack'

# connect to MQTT if configured
Thread.new { MQ.run } if CONFIG['mqtt']['uri']

# start a background thread which will listen for inverter packets
# in itself, this is wrapped in another thread to try and address
# reports of MQ stopping being updated. Unable to reproduce atm so
# this is a bodge.
Thread.new do
  loop do
    t = Thread.new do
      begin
        LOGGER.info("Creating new Master LuxListener")
        LuxListener.run(host: CONFIG['lxp']['host'], port: CONFIG['lxp']['port'], slave: 0)
      rescue StandardError => e
        LOGGER.error "LuxListener Master Thread: #{e}"
        LOGGER.debug e.backtrace.join("\n")
      end
    end
    t.join
    LOGGER.info 'Restarting Master LuxListener Thread in 5 seconds'
    sleep 5
  end
end

## start a separate for the slave controller
Thread.new do
  loop do
    tslave = Thread.new do
      begin
        LOGGER.info("Creating new Slave LuxListener")
        LuxListener.run(host: CONFIG['lxp']['host_slave'], port: CONFIG['lxp']['port_slave'], slave: 1)
      rescue StandardError => e
        LOGGER.error "LuxListener Slave Thread: #{e}"
        LOGGER.debug e.backtrace.join("\n")
      end
    end
    tslave.join
    LOGGER.info 'Restarting Slave LuxListener Thread in 5 seconds'
    sleep 5
  end
end

# MQTT stuff
Rack::Server.start(Host: CONFIG['server']['listen_host'] || CONFIG['server']['host'],
                   Port: CONFIG['server']['port'],
                   app: App.freeze.app)
