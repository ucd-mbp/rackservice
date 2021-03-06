require 'rackservice'

require 'minitest/spec'
require 'minitest/autorun'
require 'net/http'
require 'rack'
require 'stringio'

NULLOG = Logger.new('/dev/null')

class TestAPI < RackService::API
  def initialize(logio)
    @log = Logger.new(logio)
    @log.formatter = RackService::LogFormatter
  end
  def log()
    @log.info 'message'
  end
  def get(param, name:nil)
    "get #{param} #{name}"
  end
  def get_complex(param)
    param
  end
  def get_json(param, name:nil)
    ['get_json', param, name]
  end
  post
  def post(param, name:nil)
    "post #{param} #{name}"
  end
end

describe RackService do
  PORT = 4560
  DATA = {'name'=>'value'}
  before do
    @logio = StringIO.new
    rack = Rack::Server.new(Host:'127.0.0.1', Port:PORT, server:'webrick', AccessLog: NULLOG, Logger: NULLOG, app:TestAPI.new(@logio))
    t = Thread.new{rack.start{|s|@server=s}}; while !(Net::HTTP.get_response('localhost', '/', PORT) rescue nil); t.join(0); end
  end
  after do
    @server.shutdown
  end
  def request req
    Net::HTTP.new('localhost', PORT).request req
  end
  it "can log" do
    request Net::HTTP::Get.new('/log', {'User-Agent' => 'RackService MiniTest'})
    @logio.rewind
    @logio.read.must_match /^[^\n]+ 127\.0\.0\.1 "-" "RackService MiniTest" log message\n$/
  end
  it "can get help" do
    request(Net::HTTP::Get.new('/')).body.must_match /^TestAPI v.*/
  end
  it "can get" do
    request(Net::HTTP::Get.new('/get/param?'+URI::encode_www_form(DATA))).body.must_equal "get param value"
  end
  it "can get JSON" do
    JSON.parse(request(Net::HTTP::Get.new('/get_json/param?'+URI::encode_www_form(DATA))).body).must_equal ['get_json', 'param', 'value']
  end
  it "can post" do
    req = Net::HTTP::Post.new('/post/param')
    req.form_data = DATA
    request(req).body.must_equal "post param value"
  end
  it "can get with JSON" do
    request(Net::HTTP::Get.new('/get/param?'+URI::encode_www_form_component(DATA.to_json))).body.must_equal "get param value"
  end
  it "can get with JSON positional parameter" do
    JSON.parse(request(Net::HTTP::Get.new('/get_complex/'+URI::encode_www_form_component(DATA.to_json))).body).must_equal DATA
  end
  it "can post with JSON" do
    req = Net::HTTP::Post.new('/post/param')
    req.content_type = 'application/json'
    req.body = DATA.to_json
    request(req).body.must_equal "post param value"
  end
end
