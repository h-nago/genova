require_relative '../config/environment'
require_relative '../lib/genova/slack/commands'

Slack::RealTime::Client.configure do |config|
  config.websocket_ping = 10
end

SlackRubyBot.configure do |config|
  logger = Logger.new('log/slack-ruby-bot.log')
  logger.extend(ActiveSupport::Logger.broadcast(ActiveSupport::Logger.new(STDOUT)))

  config.logger = logger
end

SlackRubyBotServer::App.instance.prepare!
SlackRubyBotServer::Service.start!

run SlackRubyBotServer::Api::Middleware.instance
