require 'rubygems'
require 'bundler'
require 'mechanize'

puts ENV['SSL_CERT_DIR']
puts ENV['SSL_CERT_FILE']
puts "------"

a = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
}
union_url = "https://www.uwsu.com"
homepage = a.get(union_url)
potential_event_page_links = homepage.links_with(href: /event/)
potential_event_page_links += homepage.links_with(text: /event/i)
potential_event_page_links.uniq! { |link| link.href }

puts "Found : #{potential_event_page_links.size} potential events_pages"

potential_event_page_links.each { |link| puts "#{link.text.strip}: #{link.href}"  }

#using the first link for speeds
#

