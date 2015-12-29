#!/usr/bin/env ruby
#
# check-megaraid.rb
#
# Author: Matteo Cerutti <matteo.cerutti@hotmail.co.uk>
#

require 'sensu-plugin/check/cli'
require 'json'
require 'socket'

class CheckMegaRAID < Sensu::Plugin::Check::CLI
  option :storcli_cmd,
         :description => "Path to StorCLI executable (default: /opt/MegaRAID/storcli/storcli64)",
         :short => "-c <PATH>",
         :long => "--storcli-cmd <PATH>",
         :default => "/opt/MegaRAID/storcli/storcli64"

  option :controller_id,
         :description => "Comma separated list of Controller ID(s) (default: all)",
         :short => "-C <ID>",
         :long => "--controller-id <ID>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :warn,
         :description => "Warn instead of throwing a critical failure",
         :short => "-w",
         :long => "--warn",
         :boolean => false

  def initialize()
    super

    if config[:controller_id].length > 0
      controller_id = config[:controller_id]
    else
      controller_id = get_controllers()
    end

    # populate each controller
    controllers = {}

    controller_id.each do |cid|
      cdata = JSON.parse(%x[#{config[:storcli_cmd]} /c#{cid} show all J].chomp)
      edata = JSON.parse(%x[#{config[:storcli_cmd]} /c#{cid}/eall show J].chomp)

      controllers[cid] = {}
      controllers[cid]['status'] = cdata['Controllers'][0]['Response Data']['Status']
      controllers[cid]['virtualdisks'] = cdata['Controllers'][0]['Response Data']['VD LIST']
      controllers[cid]['physicaldisks'] = cdata['Controllers'][0]['Response Data']['PD LIST']
      controllers[cid]['battery'] = cdata['Controllers'][0]['Response Data']['BBU_Info']
      controllers[cid]['enclosures'] = edata['Controllers'][0]['Response Data']['Properties']
    end

    @controllers = controllers
  end

  def get_controllers()
    data = JSON.parse(%x[#{config[:storcli_cmd]} show J].chomp)
    data['Controllers'][0]['Response Data']['System Overview'].map { |i| i['Ctl'] }
  end

  def send_client_socket(data)
    sock = UDPSocket.new
    sock.send(data + "\n", 0, "127.0.0.1", 3030)
  end

  def send_ok(check_name, msg)
    event = {"name" => check_name, "status" => 0, "output" => "OK: #{msg}", "handler" => config[:handler]}
    send_client_socket(event.to_json)
  end

  def send_warning(check_name, msg)
    event = {"name" => check_name, "status" => 1, "output" => "WARNING: #{msg}", "handler" => config[:handler]}
    send_client_socket(event.to_json)
  end

  def send_critical(check_name, msg)
    event = {"name" => check_name, "status" => 2, "output" => "CRITICAL: #{msg}", "handler" => config[:handler]}
    send_client_socket(event.to_json)
  end

  def send_unknown(check_name, msg)
    event = {"name" => check_name, "status" => 3, "output" => "UNKNOWN: #{msg}", "handler" => config[:handler]}
    send_client_socket(event.to_json)
  end

  def run
    problems = 0

    @controllers.each do |id, controller|
      check_name = "megaraid-ctl_#{id}-status"
      if controller['status']['Controller Status'].downcase != "optimal"
        msg = "Controller #{id} in not healthy (Status: #{controller['status']['Controller Status']})"
        if config[:warn]
          send_warning(check_name, msg)
        else
          send_critical(check_name, msg)
        end
        problems += 1
      else
        send_ok(check_name, "Controller #{id} is healthy")
      end

      controller['virtualdisks'].each do |vd|
        check_name = "megaraid-ctl_#{id}-vd_#{vd['DG/VD']}-state"
        if vd['State'].downcase != "optl"
          msg = "Controller #{id} VD #{vd['DG/VD']} is not healthy (Status: #{vd['State']})"
          if config[:warn]
            send_warning(check_name, msg)
          else
            send_critical(check_name, msg)
          end
          problems += 1
        else
          send_ok(check_name, "Controller #{id} VD #{vd['DG/VD']} is healthy")
        end
      end

      controller['physicaldisks'].each do |pd|
        check_name = "megaraid-ctl_#{id}-pd_#{pd['EID:Slt']}-state"
        if pd['State'].downcase != "onln"
          msg = "Controller #{id} PD #{pd['EID:Slt']} is not healthy (Status: #{pd['State']})"
          if config[:warn]
            send_warning(check_name, msg)
          else
            send_critical(check_name, msg)
          end
          problems += 1
        else
          send_ok(check_name, "Controller #{id} PD #{pd['EID:Slt']} is healthy")
        end
      end

      controller['enclosures'].each do |enc|
        check_name = "megaraid-ctl_#{id}-enc_#{enc['EID']}-state"
        if enc['State'].downcase != "ok"
          msg = "Controller #{id} enclosure #{enc['EID']} is not healthy (Status: #{enc['State']})"
          if config[:warn]
            send_warning(check_name, msg)
          else
            send_critical(check_name, msg)
          end
          problems += 1
        else
          send_ok(check_name, "Controller #{id} enclosure #{enc['EID']} is healthy")
        end
      end

      controller['battery'].each do |bbu|
        check_name = "megaraid-ctl_#{id}-bbu_#{bbu['EID']}-state"
        if bbu['State'].downcase != "optimal"
          msg = "Controller #{id} BBU #{bbu['Model']} is not healthy (Status: #{bbu['State']})"
          if config[:warn]
            send_warning(check_name, msg)
          else
            send_critical(check_name, msg)
          end
          problems += 1
        else
          send_ok(check_name, "Controller #{id} BBU #{bbu['Model']} is healthy")
        end
      end
    end

    if problems > 0
      message "Found #{problems} problems"
      warning if config[:warn]
      critical
    else
      ok "All controllers (#{@controllers.keys.join(', ')}) are healthy"
    end
  end
end
