#!/usr/bin/env ruby

require 'net/http'
require 'json'

SENSU_API_ENDPOINT = 'https://localhost:4567'

# Keep user and password blank to disable auth
SENSU_API_USER = 'apiuser'
SENSU_API_PASSWORD = 'sensu_api_password'

SCHEDULER.every '30s', :first_in => 0 do |job|

  critical_count = 0
  warning_count = 0
  client_warning = Array.new
  client_critical = Array.new
  auth = (SENSU_API_USER.empty? || SENSU_API_PASSWORD.empty?) ? false : true

  uri = URI(SENSU_API_ENDPOINT+"/clients")
  req = Net::HTTP::Get.new(uri)
  req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
  response = Net::HTTP.start(uri.hostname, uri.port) {|http|
    http.request(req)
  }

  clients = JSON.parse(response.body)
  clients.each do |client|
    warn = Array.new
    crit = Array.new
    uri = URI(SENSU_API_ENDPOINT+"/clients/#{client['name']}/history")
    req = Net::HTTP::Get.new(uri)
    req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
    response = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }
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
