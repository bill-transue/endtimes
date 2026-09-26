#!/usr/bin/env bash
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails db:prepare
bin/rails db:seed
