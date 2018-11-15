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

a.get('https://keelesu.com/') do |page|
  page.links.each do |link|
    text = link.text.strip
    next unless text.length > 0
    puts text
  end
end