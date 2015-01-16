require 'goliath'
require 'goliath/rack/templates'

class Kittens::Server < Goliath::API

  include Goliath::Rack::Templates

  if(['HTTP_AUTH_USER', 'HTTP_AUTH_PASSWORD'].any? { |v| !ENV[v].nil? && ENV[v] != '' })
    use Rack::Auth::Basic, "Heroku Log Store" do |username, password|
      authorized?(username, password)
    end
  end

  def response(env)
    case env['PATH_INFO']
    when '/drain' then
      store_log(env[Goliath::Request::RACK_INPUT].read) if(env[Goliath::Request::REQUEST_METHOD] == 'POST')
      [200, {}, "drained"]
    when '/404' then
      [200, {}, haml(:not_found, locals: { not_found_errors: Kittens::Stats.not_found_errors })]
    when '/' then
      locals = {
        protected: self.class.protected?, env: env,
        username: ENV['HTTP_AUTH_USER'], password: ENV['HTTP_AUTH_PASSWORD']
      }

      locals[:server_errors]   = Kittens::Stats.server_errors
      locals[:timeouts]        = Kittens::Stats.timeouts
      locals[:postgres_events] = Kittens::Stats.postgres_events

      [200, {}, haml(:index, locals: locals)]
    else
      raise Goliath::Validation::NotFoundError
    end
  end

  private

  def store_log(log_str)
    event_data = HerokuLogParser.parse(log_str)
    event_data.each do |evt|
      if router_error?(evt)
        data = evt[:message_data].slice('code', 'desc', 'method', 'path', 'host', 'request_id', 'fwd', 'dyno', 'connect', 'service', 'status')
        data['emitted_at'] = evt[:emitted_at]
        DB[:router_errors].insert data
      elsif interesting_postgres_event?(evt)
        DB[:postgres_events].insert evt.slice(:emitted_at, :proc_id, :message)
      end
    end
  rescue => e
    puts e.inspect
    puts log_str.inspect
    puts event_data.inspect
  end

  def router_error?(evt)
    return unless evt[:proc_id] == 'router'
    return if evt[:message_data]['status'] < 400
    return if evt[:message_data]['status'] == 401 # Unauthorized
    return if evt[:message_data]['code'] == 'H18' # Request Interrupted

    true
  end

  def interesting_postgres_event?(evt)
    return unless evt[:proc_id].include?('postgres')
    return if !evt[:message_data].empty? # Stats
    return if evt[:message].include?('checkpoint')

    true
  end

  def self.protected?
    ['HTTP_AUTH_USER', 'HTTP_AUTH_PASSWORD'].any? { |v| !ENV[v].nil? && ENV[v] != '' }
  end

  def self.authorized?(u, p)
    [u, p] == [ENV['HTTP_AUTH_USER'], ENV['HTTP_AUTH_PASSWORD']]
  end
end
