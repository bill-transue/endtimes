#!/usr/bin/env bash
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails db:prepare

# Queue/cache/cable share DATABASE_URL. db:prepare only loads primary schema.rb,
# and db/queue_migrate (etc.) are empty, so Solid tables are never created.
# schema:load uses force: :cascade — run only when the tables are missing.
table_state="$(bundle exec ruby -rpg -e '
  conn = PG.connect(ENV.fetch("DATABASE_URL"))
  exists = conn.exec("SELECT to_regclass('\''public.solid_queue_recurring_tasks'\'')").getvalue(0, 0)
  print(exists ? "present" : "missing")
')"

if [ "$table_state" = "missing" ]; then
  echo "Loading queue, cache, and cable schemas"
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:queue
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:cache
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:cable
else
  echo "solid_queue_recurring_tasks already exists; skipping queue/cache/cable schema load"
fi

bin/rails db:seed
