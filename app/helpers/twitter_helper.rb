module TwitterHelper
  TWITTER_URL = "http://www.twitter.com/swingoutlondon"
  
  def tweet_message
    begin
      # Cache tweets for 10 minutes, timeout after 2 seconds      
      message = APICache.get('latest_tweet', :cache => 600, :timeout => 2) do
        logger.info "[INFO]: Retrieving Twitter message from twitter instead of the cache"
        get_tweet_message
      end
    rescue Dalli::RingError => e
      # API cache uses MemCachier via Dalli. Dalli throws an error if it can't contact the store.
      logger.error "[ERROR]: Dalli::RingError - MemCachier isn't available? #{e}'"
      
      # The store isn't available, so get a fresh message:
      get_tweet_message
    rescue => e
      # Catch-all: so that the site doesn't crash when caching breaks
      logger.error "[ERROR]: #{e.class} - #{e.message}" 
      e.backtrace.each { |line| logger.error line }
      
      # Caching isn't working, so get a fresh message:
      get_tweet_message
    end
    
    if message.blank?
      # This should only ever happen if:
      # 1. The memcached store is unavailable
      # 2. api_cache threw an exception
      # 3. api_cache can't retrieve the tweet for over a day (very unlikely)
      failure_message
    else
      message
    end
  end
  
  def get_tweet_message
    begin
      tweet = Twitter.user_timeline("swingoutlondon").first
    rescue Exception => e
       # The call to the twitter api fails if it can't reach twitter, so we need to handle this           
      logger.error "[ERROR]: #{e.class} - Failed to get latest tweet with message '#{e}'"
      raise APICache::InvalidResponse
    end
    construct_message(tweet)
  end

  def construct_message(tweet)
    # tweet is a Hashie::Mash, so acts like an object
    created_date_string = tweet.created_at.to_s(:timepart) + " on " + tweet.created_at.to_s(:short_date)
    
    tweet.text.twitterify + " " + link_to(created_date_string, "#{TWITTER_URL}/status/#{tweet.id}", :class => "tweet_created")
  end
  
  def failure_message
    "Sorry, for some reason we can't load the latest tweet. Please visit the " + 
    link_to("Swing Out London Twitter feed", "#{TWITTER_URL}", :title => "Swing Out London on Twitter")
  end
end