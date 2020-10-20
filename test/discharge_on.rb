#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../boot'

lc = LuxController.new(host: CONFIG['lxp']['host'],
                       port: CONFIG['lxp']['port'],
                       serial: CONFIG['lxp']['serial'],
                       datalog: CONFIG['lxp']['datalog'])

lc.discharge_pct = 100

lc_slave = LuxController.new(host: CONFIG['lxp']['host_slave'],
    port: CONFIG['lxp']['port_slave'],
    serial: CONFIG['lxp']['serial_slave'],
    datalog: CONFIG['lxp']['datalog_slave'])

lc_slave.discharge_pct = 100


