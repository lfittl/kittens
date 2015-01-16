require 'active_support/core_ext/numeric'

module Kittens::Stats
  extend self

  SQL_500_ERRORS = "status BETWEEN 500 AND 599 AND (code IS NULL OR code NOT IN ('H12', 'H18'))"

  def server_errors
    router_errors.where(SQL_500_ERRORS).group_and_count(:method, :host, :path, :status).order(Sequel.desc(:count))
  end

  def timeouts
    router_errors.where(code: 'H12').group_and_count(:method, :host, :path).order(Sequel.desc(:count))
  end

  def not_found_errors
    not_founds = DB[:router_errors].where('emitted_at > ? AND status = 404', 1.hour.ago).to_a
    not_founds.each do |log|
      log[:path] = log[:path].gsub(/\/\d+\//, '/?/').gsub(/=\d+/, '=?')
    end

    not_founds
      .group_by { |l| l[:method] + l[:host] + l[:path] }
      .map { |group, elems| elems.first.merge(count: elems.size) }
      .sort_by { |l| l[:count] }
      .reverse
  end

  def postgres_events
    DB[:postgres_events].where('emitted_at > ?', 24.hours.ago).order(Sequel.desc(:emitted_at))
  end

  private

  def router_errors
    DB[:router_errors].where('emitted_at > ?', 24.hours.ago)
  end
end
