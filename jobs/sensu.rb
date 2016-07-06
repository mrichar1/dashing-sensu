#!/usr/bin/env ruby

require 'net/http'
require 'json'

SENSU_API_ENDPOINT = URI.parse('http://localhost:4567')

# Set user and password if you want to enable authentication.
# Otherwise, leave them blank.
SENSU_API_USER = ''
SENSU_API_PASSWORD = ''

SCHEDULER.every '30s', :first_in => 0 do |job|

  critical_count = 0
  warning_count = 0
  client_warning = Array.new
  client_critical = Array.new
  client_stash = Array.new
  auth = (SENSU_API_USER.empty? || SENSU_API_PASSWORD.empty?) ? false : true

  http = Net::HTTP.new(SENSU_API_ENDPOINT.host, SENSU_API_ENDPOINT.port)
  if SENSU_API_ENDPOINT.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  events_req = Net::HTTP::Get.new(SENSU_API_ENDPOINT.path + "/events")
  events_req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
  events_response = http.request(events_req)

  stash_req =  Net::HTTP::Get.new(SENSU_API_ENDPOINT.path + "/stashes")
  stash_req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
  stash_response = http.request(stash_req)

  events = JSON.parse(events_response.body)
  stashes = JSON.parse(stash_response.body)

  warn = Array.new
  crit = Array.new
  stash = Array.new
  silence = {}
  stashes.each do |stash|
    type, client, check = stash['path'].split('/')
    if type == 'silence'
      silence[client] = check
    end
  end

  events.each do |event|
    client_name = event['client']['name']
    if silence.key?(client_name)
      # If value is nil, whole client is silenced
      if silence[client_name].nil?
       next
      elsif silence[client_name] && silence[client_name] == event['check']['name']
        next
      end
    end
    status = event['check']['status']
    if status == 1
      warn.push(event)
      warning_count += 1
    elsif status == 2
      crit.push(event)
      critical_count += 1
    end
  end
  if !warn.empty?
    warn.each do |entry|
      client_warning.push( {:label=>entry['client']['name'], :value=>entry['check']['name']} )
    end
  end
  if !crit.empty?
    crit.each do |entry|
      client_critical.push( {:label=>entry['client']['name'], :value=>entry['check']['name']} )
    end
  end
  if !silence.empty?
    silence.each do |client, check|
      client_stash.push( {:label=>client, :value=>check} )
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
  send_event('sensu-stash-list', { items: client_stash })

end
