# LuxPower Inverter / Octopus Time-of-use Tariff Integration

This is a Ruby script to parse [Octopus ToU tariff](https://octopus.energy/agile/) prices and control a [LuxPower ACS inverter](https://www.luxpowertek.com/ac-ess.html) according to rules you specify.

The particular use-case of this is to charge your home batteries when prices are cheap, and use that power at peak times.

Note that I've superceded this project with a more generic "LXP to MQTT bridge" type project, which tries to be less opinionated and focuses more on just getting messages between your inverter and MQTT. You can find it at https://github.com/celsworth/lxp-bridge.

## Installation

You'll need Ruby - at least 2.3 should be fine, which can be found in all good Linux distributions.

This apt-get command also installs the Ruby development headers and a compiler so Ruby can build extensions as part of installing dependencies:

```
sudo apt-get install ruby ruby-dev ruby-bundler git build-essential
```

Clone this repository to your machine:

```
git clone https://github.com/celsworth/octolux.git
cd octolux
```

Now install the gems. You may occasionally need to re-run this as I update the repository and bring in new dependencies or update existing ones.  This will install gems to `./vendor/bundle`, and so should not need root:

```
bundle update
```

Create a `config.ini` using the `doc/config.ini.example` as a template:

```
cp doc/config.ini.example config.ini
```

This script needs to know:

* where to find your Lux inverter, host and port.
* the serial numbers of your inverter and datalogger (the plug-in WiFi unit), which are normally printed on the sides.
* how many batteries you have, which determines the maximum charge rate (used in agile_cheap_slots rules)
* which Octopus tariff you're on, AGILE-18-02-21 is my current one for Octopus Agile.
* if you're using MQTT, where to find your MQTT server.

Copy `rules.rb` from the example as a starting point:

```
cp doc/rules.example.5p.rb rules.rb
```

The idea behind keeping the rules separate is you can edit it and be unaffected by any changes to the main script in the git repository (hopefully).

### Inverter Setup

Moved to a separate document, see [INVERTER_SETUP.md](doc/INVERTER_SETUP.md).


## Usage

There are two components.

### server.rb

`server.rb` is a long-running process that we use for background work. In particular, it monitors the inverter for status packets (these include things like battery state-of-charge).

It starts a HTTP server which `octolux.rb` can then query to get realtime inverter data. It can also connect to MQTT and publish inverter information there. See [MQ.md](doc/MQ.md) for more information about this.

It's split like this because there's no way to ask the inverter for the current battery SOC. You just have to wait (up to two minutes) for it to tell you. The server will return the latest SOC on-demand via HTTP.

You can use the provided systemd unit file to run the server. The instructions below will start it immediately, and then automatically on reboot. You may need to edit `octolux_server.service` before copying it into place, unless your installation is in `/home/pi/octolux`. You'll need to be root to do these steps:

```
cp systemd/octolux_server.service /etc/systemd/system
systemctl start octolux_server.service
systemctl enable octolux_server.service
```

The logs can then be seen with `journalctl -u octolux_server.service`.

### octolux.rb

`octolux.rb` is intended to be from cron, and enables or disables AC charge depending on the logic written in `rules.rb` (you'll need to copy/edit an example from docs/).

There's also a wrapper script, `octolux.sh`, which will divert output to a logfile (`octolux.log`), and also re-runs `octolux.rb` if it fails the first time (usually due to transient failures like the inverter not responding, which can occasionally happen). You'll want something like this in cron:

```
0,30 * * * * /home/pi/octolux/octolux.sh
```

To complement the wrapper script, there's a log rotation script which you can use like this:

```
59 23 * * * /home/pi/octolux/rotate.sh
```

This will move the current `octolux.log` into `logs/octolux.YYYYMMDD.log` at 23:59 each night.


## Development Notes

In your `rules.rb`, you have access to a few objects to do some heavy lifting.

*`octopus`* contains Octopus tariff price data. The most interesting method here is `price`:

  * `octopus.price` - the current tariff price, in pence
  * `octopus.prices` - a Hash of tariff prices, starting with the current price. Keys are the start time of the price, values are the prices in pence.

*`lc`* is a LuxController, which can do the following:

  * `lc.charge(true)` - enable AC charging
  * `lc.charge(false)` - disable AC charging
  * `lc.discharge(true)` - enable forced discharge
  * `lc.discharge(false)` - disable forced discharge
  * `lc.charge_pct` - get AC charge power rate, 0-100%
  * `lc.charge_pct = 50` - set AC charge power rate to 50%
  * `lc.discharge_pct` - get discharge power rate, 0-100%
  * `lc.discharge_pct = 50` - set discharge power rate to 50%
  * `lc.charge_amount_pct` - get AC Battery Charge Level, 0-100%
  * `lc.charge_amount_pct = 50` - set AC Battery Charge Level to 50%


Forced discharge may be useful if you're paid for export and you have a surplus of stored power when the export rate is high.

Setting the power rates is probably a bit of a niche requirement. Note that discharge rate is *all* discharging, not just forced discharge. This can be used to cap the power being produced by the inverter. Setting it to 0 will disable discharging, even if not charging.
