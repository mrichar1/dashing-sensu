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
  client_silenced = Array.new
  auth = (SENSU_API_USER.empty? || SENSU_API_PASSWORD.empty?) ? false : true

  http = Net::HTTP.new(SENSU_API_ENDPOINT.host, SENSU_API_ENDPOINT.port)
  if SENSU_API_ENDPOINT.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  events_req = Net::HTTP::Get.new(SENSU_API_ENDPOINT.path + "/events")
  events_req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
  events_response = http.request(events_req)

  silenced_req =  Net::HTTP::Get.new(SENSU_API_ENDPOINT.path + "/silenced")
  silenced_req.basic_auth SENSU_API_USER, SENSU_API_PASSWORD if auth
  silenced_response = http.request(silenced_req)

  events = JSON.parse(events_response.body)
  silenced = JSON.parse(silenced_response.body)

  warn = Array.new
  crit = Array.new
  silence = {}
  silenced.each do |sil|
    type, client, check = sil['id'].split(':')
    silence[client] = check
  end

  events.each do |event|
    client_name = event['client']['name']
    if silence.key?(client_name)
      # If value is *, whole client is silenced
      if silence[client_name] == '*'
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
      client_silenced.push( {:label=>client, :value=>check} )
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
  send_event('sensu-silenced-list', { items: client_silenced })

end
