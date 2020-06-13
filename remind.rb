require 'dotenv'
require 'json'
require 'octokit'
require 'slack-ruby-client'

# no overload on production
Dotenv.load
%w(GITHUB_API_TOKEN SLACK_API_TOKEN SLACK_CHANNEL).each do |key|
  raise "ENV['#{key}'] is nil!" if ENV[key].nil?
end

def in_business_time?
  localtime = Time.now.localtime('+09:00')
  return false if localtime.saturday? || localtime.sunday?
  return false if localtime.hour < 8 || localtime.hour > 22

  true
end

github_client = Octokit::Client.new(access_token: ENV['GITHUB_API_TOKEN'])
slack_client = Slack::Web::Client.new(token: ENV['SLACK_API_TOKEN'])

notifications = github_client.notifications(participating: true)

return if notifications.empty?
unless ENV['RUBY_ENV'] == 'development'
  return unless in_business_time?
end

attachments = notifications.map do |n|
  {
    color: '#36a64f',
    author_name: n.repository.name,
    author_link: n.repository.html_url,
    title: n.subject.title,
    title_link: n.subject.url.gsub('api.github.com/repos', 'github.com').gsub('/pulls/', '/pull/'),
    footer: n.reason,
    ts: n.updated_at.to_i
  }
end

message = {
  text: 'Unread notifications',
  attachments: attachments
}

slack_client.chat_postMessage(
  channel: ENV['SLACK_CHANNEL'],
  username: 'octocat',
  icon_emoji: 'octocat',
  **message
)
