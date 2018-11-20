class Scraper

  attr_accessor :targets
  attr_accessor :site_map
  attr_accessor :items_alias

  def initialize(options = {})
    if options[:scraper].nil?
      @agent = Mechanize.new { |agent|
        agent.user_agent_alias = 'Mac Safari'
        agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      }
    end
    @targets = [] if options[:targets].nil?
    @site_map = "/sitemap" if options[:site_map].nil?
    @items_alias = :items if options[:items_alias].nil?
    @items = []

    self.class.send(:define_method,@items_alias) { @items }
    self.class.send(:define_method,(@items_alias.to_s + "=").to_sym) { |params| @items = params}

  end

end