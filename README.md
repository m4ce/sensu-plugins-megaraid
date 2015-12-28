# Sensu plugin for monitoring LSI MegaRAID devices

A sensu plugin to monitor LSI MegaRAID devices.

The plugin generates multiple OK/WARN/CRIT/UNKNOWN events via the sensu client socket (https://sensuapp.org/docs/latest/clients#client-socket-input)
so that you do not miss state changes when monitoring multiple controllers, enclosures, virtual disks etc.

## Usage

The plugin accepts the following command line options:

```
Usage: check-megaraid.rb (options)
    -C, --controller-id <ID>         Comma separated list of Controller ID(s) (default: all)
    -c, --storcli-cmd <PATH>         Path to StorCLI executable (default: /opt/MegaRAID/storcli/storcli64)
    -w, --warn                       Warn instead of throwing a critical failure
```

## Author
Matteo Cerutti - <matteo.cerutti@hotmail.co.uk>
