# Mostly a restructuring of Ryan Smith's work for l2met
# https://github.com/ryandotsmith/l2met

module Parsley
  module Flavors
    class Heroku < Parsley::Parser

      protected

      # http://tools.ietf.org/html/rfc5424#page-8
      # frame <prority>version time hostname <appname-missing> procid msgid [no structured data = '-'] msg
      # 120 <40>1 2012-11-30T06:45:29+00:00 heroku web.3 d.73ea7440-270a-435a-a0ea-adf50b4e5f5a - State changed from starting to up

      def line_regex
        @line_regex ||= /\<(\d+)\>(1) (\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\+00:00) ([a-z0-9-]+) ([a-z0-9\-\_\.]+) ([a-z0-9\-\_\.]+) (\-) (.*)$/
      end

      # Heroku's http log drains (https://devcenter.heroku.com/articles/labs-https-drains)
      # utilize octet counting framing (http://tools.ietf.org/html/draft-gerhards-syslog-plain-tcp-12#section-3.4.1)
      # for transmission of syslog messages over TCP. This method override is required to properly parse and delimit
      # individual syslog messages, many of which may be contained in a single packet.
      #
      # I am still uncertain if this is the place for transport layer protocol handling. I suspect not.
      #
      def lines(&block)
        d = data
        while d && d.length > 0
          if matching = d.match(/^(\d+) /) # if have a counting frame, use it
            num_bytes = matching[1].to_i
            frame_offset = matching[0].length
            line_end = frame_offset + num_bytes
            msg = data[frame_offset..line_end]
            yield msg
            d = d[line_end..d.length]
          elsif matching = d.match(/\n/) # Newlines = explicit message delimiter
            d = matching.post_match
          else
            STDERR.puts("Unable to parse: #{d}")
            return
          end
        end
      end

      # Heroku is missing the appname token, so need manual override here to match w/ regex
      def event_data(matching)
        event = {}
        event[:priority] = matching[1].to_i
        event[:syslog_version] = matching[2].to_i
        event[:emitted_at] = nil?(matching[3]) ? nil : Time.parse(matching[3]).utc
        event[:hostname] = interpret_nil(matching[4])
        event[:appname] = nil
        event[:proc_id] = interpret_nil(matching[5])
        event[:msg_id] = interpret_nil(matching[6])
        event[:structured_data] = interpret_nil(matching[7])
        event[:message] = interpret_nil(matching[8])
        event
      end
    end
  end
end