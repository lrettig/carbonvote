require "bundler/setup"
require 'sinatra/base'
require "sinatra/reloader"
require "sinatra/config_file"
require "sinatra/json"
require 'redis'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  register Sinatra::ConfigFile
  config_file 'settings.yml'

  helpers do
    def redis
      @redis ||= Redis.new(url: settings.redis_url)
    end

    def last_block
      redis.get('processed-block-number') || 0
    end

    def get_amount(name)
      key = settings.contract_addresses[name]
      (redis.get("#{key}-amount") || 0).to_f
    end

    def yes_vote_amount
      @yes_vote_amount ||= get_amount(:yes_contract).round(4)
    end

    def no_vote_amount
      @no_vote_amount ||= get_amount(:no_contract).round(4)
    end

    def precentage(n, base)
      return 0.0 if base.zero?

      (n.to_f / base.to_f * 100).round(4)
    end

    def total_amount
      @total_amount ||= yes_vote_amount + no_vote_amount
    end

    def yes_precentage
      precentage(yes_vote_amount, total_amount)
    end

    def no_precentage
      precentage(no_vote_amount, total_amount)
    end
  end

  get '/' do
    erb :index, locals: {
      settings: settings,
      last_block: last_block,
      no_vote_amount: no_vote_amount,
      yes_vote_amount: yes_vote_amount
    }
  end

  get '/vote' do
    json({
      yes_precentage: yes_precentage,
      no_vote_amount: no_vote_amount,
      yes_vote_amount: yes_vote_amount,
      no_precentage: no_precentage
    })
  end
end
