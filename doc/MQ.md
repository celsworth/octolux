# MQTT Support

`server.rb` can be configured to connect to an MQTT server. For this, add a section to your `config.ini` like so;

```ini
[mqtt]
# see https://github.com/mqtt/mqtt.github.io/wiki/URI-Scheme for URI help
uri = mqtt://server:1883
```

You can use mqtts for secure connections and add username/password; see the URL for details.

## Getting Inverter Status

As mentioned in the README, the inverter sends power data (also called inputs) when it feels like it. This is every 2 minutes.

It's sent by the inverter as 3 packets in sequence, around a second apart. When we receive each one, it is published under the keys `octolux/inputs/1`, `octolux/inputs/2`, and `octolux/inputs/3`. Each one always has the same set of data, and it should look something like this:

```
$ mosquitto_sub -t octolux/inputs/+ -v
octolux/inputs/1 {"status":32,"v_bat":49.4,"soc":53,"p_pv":550,"p_charge":114,"p_discharge":0,"v_acr":247.3,"f_ac":49.96,"p_inv":0,"p_rec":116,"v_eps":247.3,"f_eps":49.96,"p_to_grid":0,"p_to_user":0,"e_pv_day":0.7,"e_inv_day":2.0,"e_rec_day":1.7,"e_chg_day":1.9,"e_dischg_day":2.4,"e_eps_day":0.0,"e_to_grid_day":0.0,"e_to_user_day":3.9,"v_bus_1":379.9,"v_bus_2":300.5}
octolux/inputs/2 {"e_pv_all":1675.6,"e_inv_all":943.9,"e_rec_all":1099.3,"e_chg_all":1251.2,"e_dischg_all":1151.6,"e_eps_all":0.0,"e_to_grid_all":124.0,"e_to_user_all":1115.8,"t_inner":43,"t_rad_1":30,"t_rad_2":30}
octolux/inputs/3 {"max_chg_curr":105.0,"max_dischg_curr":150.0,"charge_volt_ref":53.2,"dischg_cut_volt":40.0,"bat_status_0":0,"bat_status_1":0,"bat_status_2":0,"bat_status_3":0,"bat_status_4":0,"bat_status_5":192,"bat_status_6":0,"bat_status_7":0,"bat_status_8":0,"bat_status_9":0,"bat_status_inv":3}
```

Documenting all these is beyond the scope of this document, but broadly speaking:

  * `status` is 0 when idle, 16 when discharging (`p_dischg > 0`), 32 when charging (`p_charge > 0`)
  * `v_bat is battery voltage, `soc` is state-of-charge in %. `v_bus` are internal bus voltages
  * those prefixed with `p_` are intantaneous power in watts
  * `e_` are energy accumulators in `kWh` (and they're present for both today and all-time)
  * `f_` are mains Hz
  * `t_` are temperatures in celsius; internally, and both radiators on the back of the inverter
  * not really worked out what all the `bat_status_` are yet as they're usually mostly 0


You can also request this information to be sent immediately with `octolux/cmd/read_input`, with a payload of 1, 2 or 3, depending on which set of inputs you want:

```
$ mosquitto_pub -t octolux/cmd/read_input -m 1
```

This will prompt a further MQ message of `octolux/inputs/1` (as above), and additionally `octolux/result/read_input` will be sent with `OK` when it's complete.


## Controlling the Inverter

`server.rb` will subscribe to a few topics that can be used for inverter control.

In the following, "boolean" can be any of the following to mean true: `1`, `t`, `true`, `y`, `yes`, `on`. Anything else is interpreted as false.

  * `octolux/cmd/ac_charge` - send this a boolean to enable or disable AC charging. This is taking energy from the grid to charge; this does not need to be on to charge from solar.
  * `octolux/cmd/forced_discharge` - send this a boolean to enable or disable forced discharging. This is only useful if you get paid for export and the export rate is high. Normally, this should be off; this is *not* related to normal discharging operation.
  * `octolux/cmd/discharge_pct` - send this an integer (0-100) to set the discharge rate. Normally this is 100% to enable normal discharge. If you have another cheap electricity source and want the inverter to stop supplying electricity, setting this to 0 will do that.
  * `octolux/cmd/charge_pct` - send this an integer (0-100) to set the charge rate. This probably isn't terribly useful, but if you want to limit AC charging to less than the full 3600W, use this to do it.
  * `octolux/cmd/charge_amount_pct` - send this an integer (0-100) to set the charge level limit when AC charging; eg to only AC Charge up to 50%, set 50.


So for example, you could do;

```
$ mosquitto_pub -t octolux/cmd/ac_charge -m on
```

After you send the inverter a command, you'll get two responses.

The first one will be in a topic like `octolux/result/ac_charge` (where the final topic level matches the `cmd` you sent). This will be the string `OK` if the inverter replied with success, or `FAIL` if it didn't.

The second response is a little more low-level and is described fully in the next section.

## Inverter Holdings

This is quite low-level and may not be terribly useful yet; this is subject to improvement in future.

The inverter has a bunch of registers that determine current operation. There's a full list in my [lxp-packet](https://github.com/celsworth/lxp-packet/blob/master/doc/LXP_REGISTERS.txt) gem.

So for example, setting discharge percentage is register 65 (DISCHG_POWER_PERCENT_CMD from the register list).

So if I send:

```
$ mosquitto_pub -t octolux/cmd/discharge_pct -m 50
```

I should then see a message:

```
$ mosquitto_sub -t octolux/hold/+ -v
octolux/hold/65 50
```

This says the inverter has told us that register 65 now contains the value 50. If you don't see that, then the register most likely has not updated.

So, clearly for now this requires your client code to know that register 65 is what will change in response to `discharge_pct`. For this reason, the `result` topics are probably more useful for now.

However, you could use these topics to record or graph every time a register changes, regardless of *how* it was changed, since these will be published even if MQ wasn't used to action the change (eg, via LuxPower's portal or app).

Finally, if you know the register you want and want it on-demand, you can send `octolux/cmd/read_hold` with an integer message:

```
$ mosquitto_pub -t octolux/cmd/read_hold -m 65
```

This will result in `octolux/hold/65` being sent (as above) and additionally `octolux/result/read_hold` will be sent (with `OK`) once complete.
