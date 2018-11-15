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

# Using the first link for speeds

page_to_scrap = potential_event_page_links.first.click
puts ""
puts "#{page_to_scrap.title.strip}"
puts "-" * page_to_scrap.title.strip.size

event_pages = page_to_scrap.search(".event_item")
puts "Found #{event_pages.size} events"


events = event_pages.map do |event|
  name_elm = event.css("a.msl_event_name")
  name = name_elm.text
  link_path = name_elm.first['href']
  link_path = union_url + link_path unless /\/\//.match link_path
  location = event.css(".msl_event_location").text
  description = event.css(".msl_event_description").text
  puts "About to process #{link_path}"
  event_page = a.get(link_path)
  {name: name, location: location, description: description, webpage: link_path}
end

puts events