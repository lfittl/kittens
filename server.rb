require './config'
require 'goliath/rack/templates'

class HerokuLogDrain < Goliath::API

  include Goliath::Rack::Templates

  # If we've explicitly set auth, check for it. Otherwise, buyer-beware!
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
      logs = DB[:router_errors].where('emitted_at > ?', 1.hour.ago).to_a
      logs.each do |log|
        log[:path] = log[:path].gsub(/\/\d+\//, '/?/').gsub(/=\d+/, '=?')
      end
      logs = logs.group_by do |log|
        log[:method] + log[:host] + log[:path]
      end
      logs = logs.map do |group, elems|
        elems.first.merge(count: elems.size)
      end
      logs = logs.sort_by { |l| l[:count] }.reverse

      [200, {}, haml(:not_found, locals: { logs: logs })]
    when '/' then
      locals = {
        protected: self.class.protected?, env: env,
        username: ENV['HTTP_AUTH_USER'], password: ENV['HTTP_AUTH_PASSWORD']
      }

      router_errors = DB[:router_errors].where('emitted_at > ?', 24.hours.ago).order(Sequel.desc(:count))

      locals[:router_timeouts]   = router_errors.where(code: 'H12').group_and_count(:method, :host, :path)
      locals[:router_500_errors] = router_errors.where("status BETWEEN 500 AND 599 AND code NOT IN ('H12', 'H18')").group_and_count(:method, :host, :path, :status)
      locals[:postgres_events]   = DB[:postgres_events].where('emitted_at > ?', 24.hours.ago).order(Sequel.desc(:emitted_at))

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
    return if evt[:message_data]['code'] == 'H18'   # Request Interrupted

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
