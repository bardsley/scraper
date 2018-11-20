require 'rubygems'
require 'bundler'
require 'mechanize'
require 'json'

$stdout.sync = true

# takes a potential page link and fetches it
def get_event_page(event_page_link)
  link_path = event_page_link.css("a.msl_event_name").first['href']
  link_path = @union_url + link_path unless /\/\//.match link_path
  @agent.get(link_path)
end

# returns an event hash from a Mechanize page of an event paage
def get_hash_of_event_from_page(page)
  id = page.uri.path.split('/').last
  url = page.uri.to_s
  title = page.title.strip

  time_elm = page.css("#msl_event .time").first
  date_elm = page.css("#msl_event .date").first
  if date_elm || time_elm # We have explicit date and time
    date = date_elm.text unless date_elm.nil?
    time = time_elm.text unless time_elm.nil?
    date_time = "#{date} #{time}"
  elsif page.css("#msl_event .event-details p").size > 0 # specifically marked event details
    datetime_elm = page.css("#msl_event .event-details p")[0]
    date_time = datetime_elm.text unless datetime_elm.nil?
  elsif page.css("#msl_event").size > 0 # There are some events we think
    datetime_elm = page.css("#msl_event").search("h2","h3","h4")
    begin
      date_time = datetime_elm.text.split("\n").last.strip unless datetime_elm.nil?
    rescue
      date_time = datetime_elm.text.split("\n").class.to_s
    end
  end

  location_elm = page.css("#msl_event .location").first
  location_elm = page.css("#msl_event .event-details p")[1] if location_elm.nil?
  location_elm = page.css("#msl_event").search("h2","h3","h4").first if location_elm.nil?
  begin
    location = location_elm.text.split("\n").first.strip unless location_elm.nil?
  rescue
    puts "Rescued for #{page.uri}"
    puts location_elm.text unless location_elm.nil?
  end
  if location_elm.nil?
    location = "NO Location Element"
  end

  description_elms = page.css("#msl_event .desc").first
  description_elms = page.css("#msl_event .eventdescription").first if description_elms.nil?
  description = description_elms.text.gsub("Description",'').strip unless description_elms.nil?

  {id: id, url: url, title: title, date_time: date_time,location: location, description: description}
end

# Setup Mechanize
@agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
}

@events = {}

# URLS to search
# "https://www.warwicksu.com/"
union_urls = %w[https://www.rusu.co.uk/ https:///www.thesubath.com https://www.worcsu.com https://www.chestersu.com https://keelesu.com https://uwsu.com]
union_urls = %w[https://www.keelesu.com/]
union_urls.each do |union_url|
  @union_url = union_url
  events = []
  begin
    homepage = @agent.get(@union_url + "/sitemap")
  rescue
    puts "Couldn't get sitemap for #{union_url}"
    next
  end
  puts ""
  puts "Looking at #{union_url}"
  puts "="*50
  puts ""
  potential_event_listing_page_links = homepage.links_with(href: /event/)
  potential_event_listing_page_links += homepage.links_with(text: /event/i)

  # Clear any javascript Links
  potential_event_listing_page_links.delete_if { |link| /javascript/.match(link.href) }

  potential_event_listing_page_links.uniq!(&:href)
  puts "#{potential_event_listing_page_links.size} potential event listing pages"
  puts "------------------------------------"
  potential_event_listing_page_links.each_with_index { |link,i| puts "#{i}) #{link.text.strip}: #{link.href}"  }

  puts ''
  puts 'Analysing potential event listing pages'
  puts '---------------------------------------'
  potential_event_listing_page_links.each_with_index do |link,i|
    event_list_page = link.click
    next if event_list_page.class !=  Mechanize::Page # Usually a PDF linked in sitemap
    event_page_links = event_list_page.search(".event_item")

    if event_page_links.size > 0
      puts "#{i}) #{event_page_links.size} events found @ #{event_list_page.title.strip} - (#{event_list_page.uri})"
      event_pages = event_page_links.map(&method(:get_event_page)).compact
      events += event_pages.map(&method(:get_hash_of_event_from_page))
    end
  end

  events_found_count = events.size
  events.uniq! { |evt| evt[:id] }
  puts "------------------------------------------------------------------"
  puts "Results #{events.size} found (removed #{events_found_count - events.size} duplicates)"

  puts "------------------------------------------------------------------"
  @events[union_url] = events
end

puts ''
puts '========================================'
puts '              OUTPUT .json file'
puts '========================================'
puts @events.to_yaml