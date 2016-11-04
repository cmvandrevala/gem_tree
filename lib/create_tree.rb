require "faraday"
require "json"
require "pp"

conn = Faraday.new(:url => "https://rubygems.org/api/v1/gems/rails.json")


response = conn.get

json = JSON.parse( response.body, {symbolize_names: true} )

pp json.fetch(:dependencies, {}).fetch(:runtime, [])
