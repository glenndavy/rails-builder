require "bundler/setup"
require "hanami/setup"
require "hanami/model"
require_relative "../apps/web/application"
require_relative "../lib/my_hanami_one_app"

Hanami.configure do
  mount Web::Application, at: "/"

  model do
    adapter :sql, ENV["DATABASE_URL"]
  end
end
