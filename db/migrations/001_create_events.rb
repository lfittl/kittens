Sequel.migration do
  transaction

  up do
    run <<-EOS
      CREATE TABLE postgres_events (
        "emitted_at" TIMESTAMP WITH TIME ZONE,
        "proc_id" TEXT,
        "message" TEXT
      );

      CREATE INDEX ON postgres_events(emitted_at);

      CREATE TABLE router_errors (
        "emitted_at" TIMESTAMP WITH TIME ZONE,
        "code" TEXT,
        "desc" TEXT,
        "method" TEXT,
        "path" TEXT,
        "host" TEXT,
        "request_id" TEXT,
        "fwd" TEXT,
        "dyno" TEXT,
        "connect" TEXT,
        "service" TEXT,
        "status" INTEGER
      );

      CREATE INDEX ON router_errors(emitted_at);
    EOS
  end

  down do
    run "DROP TABLE IF EXISTS postgres_events;"
    run "DROP TABLE IF EXISTS router_errors;"
  end
end
