require 'rubygems'
require 'bundler'
require 'mechanize'
require 'json'

$stdout.sync = true

# takes a potential page link and fetches it
def get_group_page(group_page_link)
  link_path = group_page_link.css("a.msl_group_name").first['href']
  link_path = @union_url + link_path unless /\/\//.match link_path
  @agent.get(link_path)
end

# returns an group hash from a Mechanize page of an group paage
def get_hash_of_group_from_page(page)
  id = page.uri.path.split('/').last
  url = page.uri.to_s
  title = page.title.strip

  time_elm = page.css("#msl_group .time").first
  date_elm = page.css("#msl_group .date").first
  if time_elm.nil? && date_elm.nil?
    datetime_elm = page.css("#msl_group .group-details p")[0]
    date_time = datetime_elm.text unless datetime_elm.nil?
  else
    date = date_elm.text unless date_elm.nil?
    time = time_elm.text unless time_elm.nil?
    date_time = "#{date} #{time}"
  end

  location_elm = page.css("#msl_group .location").first
  location_elm = page.css("#msl_group .group-details p")[1] if location_elm.nil?
  location = location_elm.text unless location_elm.nil?

  description_elms = page.css("#msl_group .desc").first
  description = description_elms.text.gsub("Description",'').strip unless description_elms.nil?

  {id: id, url: url, title: title, date_time: date_time,location: location, description: description}
end

# Setup Mechanize
@agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
}

@groups = {}

# URLS to search
# "https://www.warwicksu.com/"
union_urls = %w( https://www.thesubath.com https://www.worcsu.com https://www.chestersu.com https://keelesu.com https://uwsu.com )
union_urls = %w( https://keelesu.com https://uwsu.com )
union_urls.each do |union_url|
  @union_url = union_url
  groups = []
  homepage = @agent.get(@union_url + "/sitemap")
  puts ""
  puts "Looking at #{union_url}"
  puts "="*50
  puts ""
  potential_group_listing_page_links = homepage.links_with(href: /group/)
  potential_group_listing_page_links += homepage.links_with(text: /group/i)

  # Clear any javascript Links
  potential_group_listing_page_links.delete_if { |link| /javascript/.match(link.href) }

  potential_group_listing_page_links.uniq!(&:href)
  puts "#{potential_group_listing_page_links.size} potential group listing pages"
  puts "------------------------------------"
  potential_group_listing_page_links.each_with_index { |link,i| puts "#{i}) #{link.text.strip}: #{link.href}"  }

  puts ""
  puts "Analysing potential group listing pages"
  puts "---------------------------------------"
  potential_group_listing_page_links.each_with_index do |link,i|
    group_list_page = link.click
    next if group_list_page.class !=  Mechanize::Page # Usually a PDF linked in sitemap
    group_page_links = group_list_page.search(".group_item")

    if group_page_links.size > 0
      puts "#{i}) #{group_page_links.size} groups found @ #{group_list_page.title.strip} - (#{group_list_page.uri})"
      group_pages = group_page_links.map(&method(:get_group_page)).compact
      groups += group_pages.map(&method(:get_hash_of_group_from_page))
    end
  end

  groups_found_count = groups.size
  groups.uniq! { |evt| evt[:id] }
  puts "------------------------------------------------------------------"
  puts "Results #{groups.size} found (removed #{groups_found_count - groups.size} duplicates)"

  puts "------------------------------------------------------------------"
  @groups[union_url] = groups
end

puts ''
puts '========================================'
puts '              OUTPUT .json file'
puts '========================================'
puts @groups.to_json