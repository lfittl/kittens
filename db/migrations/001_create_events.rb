Sequel.migration do
  transaction

  up do
    run <<-EOS
      CREATE table events (
        id SERIAL8 PRIMARY KEY,
        emitted_at TIMESTAMP WITH TIME ZONE,
        received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        priority INTEGER,
        syslog_version INTEGER,
        hostname TEXT,
        appname TEXT,
        proc_id TEXT,
        msg_id TEXT,
        structured_data TEXT,
        message TEXT
      );

      CREATE INDEX events_emitted_at ON events(emitted_at);
    EOS
  end

  down { run "DROP TABLE IF EXISTS events;" }
end
