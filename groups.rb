require 'rubygems'
require 'bundler'
require 'mechanize'
require 'json'

$stdout.sync = true

# takes a potential page link and fetches it
def get_group_page(group_page_link)
  link_path = group_page_link.css("a.msl-gl-link").first['href']
  link_path = @union_url + link_path unless /\/\//.match link_path
  @agent.get(link_path)
end

# returns an group hash from a Mechanize page of an group paage
def get_hash_of_group_from_page(page)
  begin
    id = page.uri.path.split('/').last.to_i
    if id == 0
      id_elm = page.search("//*[contains(@class,'org_')]")
      id = /org_([0-9]*)/.match(id_elm.attribute("class"))[1].to_i
    end
    url = page.uri.to_s
    title = page.title.strip
    path_array = page.uri.path.split('/')
    path_array.pop  # remove name/id of specific gropu
    grouping_type = path_array.pop
    parent_organisation = path_array.pop

    description_elms = page.search("//*[text()='JOIN US']").first.parent.css('.mslwidget')
    description = description_elms.text.gsub("Description",'').strip unless description_elms.nil?

    { grouping_id: id, url: url,
      grouping_type: grouping_type, parent_organisation: parent_organisation,
      title: title, description: description}
  rescue
    { status: "failed", group_id: id, page_url: page.uri}
  end
end

# Setup Mechanize
@agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
}

@groups = {}

# URLS to search
# "https://www.warwicksu.com/"
union_urls = %w[ https://www.thesubath.com https://www.worcsu.com https://www.chestersu.com https://keelesu.com https://uwsu.com ]
union_urls = %w[ https://uwusu.com ]
union_urls.each do |union_url|
  @union_url = union_url
  groups = []
  sitemap = @agent.get(@union_url + "/sitemap")
  puts ""
  puts "Looking at #{union_url}"
  puts "="*50
  puts ""

  potential_group_listing_page_links = []
  href_options = %w(activities groups clubs societies society group au sports)
  href_options.each do |pattern|
    potential_group_listing_page_links += sitemap.links_with(href: /#{pattern}/)
  end
  name_options = %w(activities groups clubs societies society group au sports)
  name_options.each do |pattern|
    potential_group_listing_page_links += sitemap.links_with(text: /#{pattern}/i)
  end

  # Clear any javascript Links
  potential_group_listing_page_links.delete_if { |link| /javascript/.match(link.href) }

  potential_group_listing_page_links.uniq!(&:href)
  puts "#{potential_group_listing_page_links.size} potential group listing pages"
  puts "------------------------------------"
  potential_group_listing_page_links.each_with_index { |link,i| puts "#{i}) #{link.text.strip}: #{link.href}" }

  puts ""
  puts "Analysing potential group listing pages"
  puts "---------------------------------------"
  potential_group_listing_page_links.each_with_index do |link,i|
    begin
    group_list_page = link.click
    next if group_list_page.class !=  Mechanize::Page # Usually a PDF linked in sitemap
    group_page_links = group_list_page.search(".group-list [data-msl-grouping-id]")

    if group_page_links.size > 0
      puts "#{i}) #{group_page_links.size} groups found @ #{group_list_page.title.strip} - (#{group_list_page.uri})"
      group_pages = group_page_links.map(&method(:get_group_page)).compact
      groups += group_pages.map(&method(:get_hash_of_group_from_page))
    end
    rescue Mechanize::RedirectLimitReachedError => e
      puts "#{i}) Failed due to redirects #{link.uri}"
    end
  end

  groups_found_count = groups.size
  groups.uniq! { |group| group[:grouping_id] }
  puts "------------------------------------------------------------------"
  puts "Results #{groups.size} found (removed #{groups_found_count - groups.size} duplicates)"

  puts "------------------------------------------------------------------"
  @groups[union_url] = groups
end

puts ''
puts '========================================'
puts '              OUTPUT .json file'
puts '========================================'
puts @groups.to_yaml