#!/usr/bin/env ruby

require 'net/http'
require 'json'

SENSU_API_ENDPOINT = 'http://localhost:4567'

SCHEDULER.every '30s', :first_in => 0 do |job|

  critical_count = 0
  warning_count = 0
  client_warning = Array.new
  client_critical = Array.new
  uri = URI.parse(SENSU_API_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  response = http.request(Net::HTTP::Get.new("/clients"))
  clients = JSON.parse(response.body)
  clients.each do |client|
    warn = Array.new 
    crit = Array.new
    response = http.request(Net::HTTP::Get.new("/clients/#{client['name']}/history"))
    checks = JSON.parse(response.body)
    checks.each do |check|
      status = check['last_status']
      if status == 1
        warn.push(check['check'])
        warning_count += 1
      elsif status == 2
        crit.push(check['check'])
        critical_count += 1
      end
    end
    if !warn.empty?
      warn.each do |entry|
        client_warning.push( {:label=>client['name'], :value=>entry} )
      end
    end
    if !crit.empty?
      crit.each do |entry|
        client_critical.push( {:label=>client['name'], :value=>entry} )
      end
    end
  end

  status = "green" 
  if critical_count > 0 
    status = "red"
  elsif warning_count > 0
    status = "yellow"
  end
 
  send_event('sensu-status', { criticals: critical_count, warnings: warning_count, status: status })
  send_event('sensu-warn-list', { items: client_warning })
  send_event('sensu-crit-list', { items: client_critical })

end
