require "faraday"
require "json"

class GemRepo
  attr_reader :cache

  def initialize
    @cache = {}
  end

  def base_url
    "https://rubygems.org/api/v1/gems"
  end

  def to_weighted_csv(gem)
    result = dependency_tree(gem)
    flattened = result.map { |t| t.values.join(",") }
    tallies = result.each_with_object(Hash.new(0)) do |dependency, hash|
      hash[dependency] += 1
    end
    tallies.map do |key, value|
      (key.values + [value]).join(",")
    end
  end

  def get_runtime_dependencies(gem)
    cached = cache.fetch(gem, nil)

    return cached if cached

    url = "#{base_url}/#{gem}.json"
    conn = Faraday.new(:url => url)
    response = conn.get
    json = JSON.parse( response.body, {symbolize_names: true} )
    runtime = json.fetch(:dependencies, {}).fetch(:runtime, [])
    development = json.fetch(:dependencies, {}).fetch(:development, [])
    cache[gem] = runtime
  end

  def dependency_tree(gem)
    dependencies = get_runtime_dependencies(gem)
    dependencies.flat_map do |dependency|
      [{ gem: gem, requires: dependency[:name] }] + dependency_tree(dependency[:name])
    end
  end

end

describe GemRepo do
  let(:repo) { GemRepo.new }

  describe "#dependency_tree" do
    let(:expectation) {
      [
        {
          gem: "sinatra",
          requires: "rack"
        },
        {
          gem: "sinatra",
          requires: "rack-protection"
        },
        {
          gem: "rack-protection",
          requires: "rack"
        },
        {
          gem: "sinatra",
          requires: "tilt"
        }
      ]
    }

    it "returns an empty array if there are no dependencies" do
      expect(repo.dependency_tree("tilt")).to eq []
    end

    it "returns a single dependency if there is only one" do
      expect(repo.dependency_tree("rack-protection")).to eq [ {gem: "rack-protection", requires: "rack"}]
    end

    it "returns a list of recursive dependency tokens" do
      expect(repo.dependency_tree("sinatra")).to eql expectation
    end
  end

  describe "#get_runtime_dependencies" do
    let(:rails_result) {
      [{:name=>"actioncable", :requirements=>"= 5.0.0.1"},
       {:name=>"actionmailer", :requirements=>"= 5.0.0.1"},
       {:name=>"actionpack", :requirements=>"= 5.0.0.1"},
       {:name=>"actionview", :requirements=>"= 5.0.0.1"},
       {:name=>"activejob", :requirements=>"= 5.0.0.1"},
       {:name=>"activemodel", :requirements=>"= 5.0.0.1"},
       {:name=>"activerecord", :requirements=>"= 5.0.0.1"},
       {:name=>"activesupport", :requirements=>"= 5.0.0.1"},
       {:name=>"bundler", :requirements=>"< 2.0, >= 1.3.0"},
       {:name=>"railties", :requirements=>"= 5.0.0.1"},
       {:name=>"sprockets-rails", :requirements=>">= 2.0.0"}]
    }

    let(:sinatra_result) {
      [{:name=>"rack", :requirements=>"~> 1.5"},
       {:name=>"rack-protection", :requirements=>"~> 1.4"},
       {:name=>"tilt", :requirements=>"< 3, >= 1.3"}]
    }

    it "returns a list of rails' runtime dependencies" do
      expect(repo.get_runtime_dependencies("rails")).to eq rails_result
    end

    it "returns a list of sinatra's runtime dependencies" do
      expect(repo.get_runtime_dependencies("sinatra")).to eq sinatra_result
    end

  end

  describe "#base_url" do
    it "has an API base url" do
      expect(repo.base_url).to eq "https://rubygems.org/api/v1/gems"
    end
  end
end

# result = repo.dependency_tree("rails")
# x = result.map { |t| t.values.join(",") }
# File.open("./test.csv", "w") { |f| f.puts(x.uniq.sort) }