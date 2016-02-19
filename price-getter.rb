require 'nokogiri'
require 'open-uri'
require 'watir-webdriver'
require 'headless'
require 'thread'

class Pool
  attr_accessor :flights, :sem

  def initialize
    @flights = [
      "CHI-TPA/2016-03-02",
      "CHI-NYC/2016-03-02",
      "CHI-SFO/2016-03-02",
      "CHI-LAX/2016-03-02",
      "CHI-DTW/2016-03-02",
      "CHI-SLC/2016-03-02",

      "CHI-TPA/2016-03-24",
      "CHI-NYC/2016-03-24",
      "CHI-SFO/2016-03-24",
      "CHI-LAX/2016-03-24",
      "CHI-DTW/2016-03-24",
      "CHI-SLC/2016-03-24",

      "ORD-TPA/2016-04-24",
      "CHI-NYC/2016-04-24",
      "CHI-SFO/2016-04-24",
      "CHI-LAX/2016-04-24",
      "CHI-DTW/2016-04-24",
      "CHI-SLC/2016-04-24",

      "ORD-TPA/2016-04-12",
      "CHI-NYC/2016-04-12",
      "CHI-SFO/2016-04-12",
      "CHI-LAX/2016-04-12",
      "CHI-DTW/2016-04-12",
      "CHI-SLC/2016-04-12"
    ]
    @sem = Mutex.new
  end
end


class PriceTracker
  def initialize
    @headless = Headless.new
    @headless.start
    @browser = Watir::Browser.new
    @@host = "https://www.kayak.com/flights/"
  end

  def self.collect_data
    flights = Pool.new.flights
    pt = PriceTracker.new
    flights.each do |f|
      price = nil
      while !price
        begin
          price = pt.get_price_today(f)
        rescue
          print 'f'
        end
      end
      open("output/#{pt.transform_flight_name(f)}.csv", 'w') do |f|
        f.puts "#{date},#{price}"
      end
    end
  end

  def self.collect_data_mt
    pool = Pool.new
    threads = []
    5.times do |i|
      Thread.new {
        pt = PriceTracker.new
        while true
          pool.sem.synchronize {
            f = pool.flights.shift
          }
          break unless f
          pt.write_price(f, pool.sem, pool.flights)
        end
      }
    end
    threads.each {|t| t.join}
  end

  def write_price(f, sem, flights)
    if price = self.get_price_today(f)
      open("output/#{transform_flight_name(f)}.csv", 'w') do |f|
        f.puts "#{date},#{price}"
      end
    else
      sem.synchronize {
        flights.push(f)
      }
    end
  end

  def get_price_today(flight)
    @browser.goto(@@host + flight)
    file_title = "#{transform_flight_name(flight)} #{date}.html"

    begin
      open('html/' + file_title, "w"){ |f| f.puts @browser.html }
    rescue
      return nil
    end

    page = Nokogiri::HTML(open('html/' + file_title))
    print '.'
    return page.css('#content_div a.results_price')[0].text.gsub('$', '')
  end

  def self.date
    Time.new.strftime("%Y-%m-%d")
  end

  def self.transform_flight_name(fl)
    fl.gsub('/', '-')
  end
end
