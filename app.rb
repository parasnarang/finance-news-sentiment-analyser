require 'rubygems'
require 'open-uri'
require 'sinatra'
require 'nokogiri'
require 'sentimental'
require 'sinatra'
require 'json'
require 'httparty'
require 'simple-rss'
require 'redis'


get '/sentiment.json' do
    content_type :json

    redis = Redis.new

    if redis[params[:q]]
        return redis[params[:q]]
    end

    # puts "Fetching Words"

    analyser = Sentimental.new
    analyser.load_defaults
    analyser.threshold = 2
    analyser.load_senti_json(File.dirname(__FILE__) + "/words.txt")

    # data = Nokogiri::HTML(open("https://www.google.com/finance?q=#{params[:q]}"))
    
    # data.css("#price-panel").each do |stock|
    #     stock.css(".pr")
    #     stock.css(".ch")
    # end

    rss = SimpleRSS.parse open("https://www.google.com/finance/company_news?q=#{params[:q]}&output=rss")
    count = 0
    articles = []
    rss.items.each do |article|
        # article.link
        # article.title
        
        news = Nokogiri::HTML(open("#{article.link}", 'User-Agent' => 'firefox'))
        title = article.title.encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_').to_s
        
        # score = analyser.score "#{news.css("p")}"
        # title_sentiment = analyser.sentiment("#{article.title}").to_s
        
        sentiment = analyser.sentiment("#{news.css("p")}").to_s

        articles << {
            :title => title,
            :link => article.link.encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_'),
            # :score => score,
            # :title_sentiment => title_sentiment,
            :sentiment => sentiment
        }

        if sentiment.include?("positive")
            count += 1
        elsif sentiment.include?("negative")
            count -= 1  
        end
    end

    verdict = if count >= 7
        "Positive sentiment but very high, be careful. May be unstable."
    elsif count >= 3 && count < 7
        "Sentiment is at a good level. May be a good time to buy."
    elsif count < 3
        "Negative sentiment. Do not buy!"
    end

    response = {
        :total_score => count,
        :verdict => verdict,
        :articles => articles
    }.to_json

    redis[params[:q]] = response
    redis.expire(params[:q], 3600*24*5)

    # puts "Response : " + response.inspect

    response
end