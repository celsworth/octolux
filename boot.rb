# frozen_string_literal: true

Thread.abort_on_exception = true

# change directory to our root path; this lets us be run from any directory, which makes cron easier
Dir.chdir(__dir__)

require 'bundler/setup'
require 'logger'

require 'inifile'
require_relative 'lib/inifile' # monkey-patch :(
require 'zeitwerk'

LOGGER = Logger.new(STDOUT)

LOADER = Zeitwerk::Loader.new
LOADER.inflector.inflect('mq' => 'MQ')
LOADER.logger = LOGGER if ENV['ZEITWERK_LOGGING']
LOADER.push_dir('lib')
LOADER.enable_reloading
LOADER.setup

CONFIG = IniFile.load('config.ini') || raise('config.ini not found!')
