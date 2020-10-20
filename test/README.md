# Test Scripts

This directory contains scripts for testing Octolux functionality.

They are split into three types, identified by the first few letters of the filename.

They all end up doing the same job, but over different transport mechanisms. So they can be used to test different parts of your setup.

* `mq_` send an MQ message to your broker, which a running `server.rb` will receive and act on
* `http_` send an HTTP request to the HTTP API on `server.rb` (TODO, not written yet)
* (no prefix) direct TCP access - communicate directly with the inverter and do not need `server.rb` running at all

So for example, `mq_ac_charge_on.rb` and `ac_charge_on.rb` both enable AC charge, but the former does it by sending an MQ message which `server.rb` receives (and that talks to the inverter), whereas `ac_charge_on.rb` opens a TCP socket to the inverter and does it directly.

Therefore, if `mq_ac_charge_on.rb` doesn't work but `ac_charge_on.rb` does, you can look to the MQ side of your configuration to find the problem.