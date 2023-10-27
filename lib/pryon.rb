# abstract collections
require 'set'
# data marshalling
require 'json'
# local db backbone
require 'pstore'
# for mqtt backbone
require 'paho-mqtt'
# for discord bot
require 'discordrb'
# for direct iot device access
require 'serialport'
# for openai tool: weather
#require 'open-weather-ruby-client'
# for openai tool: google
#require 'google_search_results'
# for openai tool: calculator
require 'eqn'
# for openai tool: ruby
#require 'safe_ruby'
# for openai tool: wikipedia
require 'wikipedia-client'
# llm wrapper
#require 'langchain'
# vector search db
#require 'qdrant'
# ai llm
#require 'openai'
# ai llm
#require 'cohere'
# web ui
require 'sinatra/base'
# ai llm 
require 'hugging_face'
require 'faraday'
require 'vlc-client'

# LLM wrapper C -> "see"
class C
  def initialize i
    @id = i
    @face = HuggingFace::InferenceApi.new(api_token: ENV['HUGGING_FACE_API_TOKEN'])
  end
  def prompt h={}, *w
    o = []
    [h[:corpus]].flatten.each_with_index { |ee,ii| if %[#{ee}].length > 0; o << Z4.corpus[ee]; end }
#    o << %[schedule: #{h[:schedule].join(", ")}] 
    if %[#{h[:my][:city]}].length > 0
#      puts %[HERE[0]: #{h[:my][:city]}]
      he = Z4.here[h[:my][:city]]
      w = he[:weather]
#      puts %[HERE[1]: #{w.keys}]
      ['daily'].each do |forecast|
#        puts %[HERE[2]: #{forecast}]
        w[forecast]['time'].each_with_index do |time, index|
          #puts %[HERE[3]: #{time} #{index}]
          oo = []
          #puts %[HERE[3.1]: #{forecast} #{w[forecast].keys}]
          w[forecast].keys.each do |key|
            #puts %[HERE[4]: #{key}]
            if key != 'time'
              kx = w[forecast][key][index]
              vx = w["#{forecast}_units"][key]
              #puts %[HERE[5]: #{kx} #{vx}]
              oo << %[#{time} #{key}: #{kx}#{vx}]
            end
          end
          o << %[weather forecast: #{oo.join(", ")}]
        end
      end
      oo = []
      w['current'].each_pair do |kk,vv|
        if kk != 'time'
          vx = w['current_units'][kk]
          #puts %[HERE[5]: #{kk} #{vv} #{vx}]
          oo << %[#{kk}: #{vv}#{vx}]
        end
      end
      o << %[the current weather is #{oo.join(", ")}]
    end
    [w].flatten.each do |we|
      puts %[WE: #{we}]
    [:my, :our, :the].each { |e|
      #puts %[--[#{e}]];
      h[e].each_pair { |k,v|
        if k.to_s == we
          #puts %[[#{e}] #{k}: #{v}];
          if v.class == Hash
            oo = []
            v.each_pair {|kk,vv| oo << %[#{kk}: #{BOT.calendar(vv.split(" "))}].gsub("  ", " ") }
            o << %[#{e} #{k} has #{oo.join(", ")}.].gsub("  ", " ")
          elsif v.class == Array
            oo = []
            #puts %[PROMPT[Array] #{v}]
            [v].flatten.each { |ex|
              if x = BOT.calendar(ex.to_s.split(" "));
                o << %[#{e} #{k} #{x}.].gsub("  ", " ")
              end
            }
          else
            if k != :user && k != :chan
              o << %[#{e} #{k} is #{v}.].gsub("  ", " ")
            end
          end
        end
      }
    }
    end
    o << [
      %[the current date and time are #{Time.now.strftime('%Y/%m/%dT%H:%M')}.]
    ].join("\n").gsub("  ", " ")
    o.uniq
    ret = o.join("\n")
    len = ret.split(" ").length
    puts %[[PROMPT] #{len} #{o}]
    return ret
  end
  def ask q, h={}
    @face.question_answering(question: q.downcase, context: prompt(h, q.gsub("?","").split(" ")))
  end
  def generate q, h={}
    @face.text_generation(input: %[#{prompt(h, q.gsub("?","").split(" "))} #{q} ])
  end
  def embed *t
    @face.embedding(input: [t].flatten)
  end
end

# reminder wrapper
class Reminder
  def initialize u
    @u = u
    @user = Z4[:user, u]
    @cal = @user.sub(:cal)
    @opts = ""
  end
  def opts= o
    @opts = o
    puts %[opts = #{@opts}]
  end
  def []= k,v
    @cal[k] = v
    save!
  end
  def erb k
    { ERB.new(k).result(binding) => ERB.new(@cal[k]).result(binding) }
  end
  def file
    o = []
    @cal.to_h.each_pair { |k,v| o << %[REM #{ERB.new(k).result(binding)} MSG #{ERB.new(v).result(binding)}] }
    o.join("\n")
  end
  def save!
    File.open("reminders/#{@u}.rem", 'w') {|f| f.write(file); }
  end
  def schedule
    `remind -ms reminders/#{@u}.rem`.chomp.gsub(' *', '').split("\n")
  end
  def calendar
    `remind -jmcw0,0,0 reminders/#{@u}.rem`.chomp.gsub("\f","").split("\n")
  end
end

# because fuck you open weather
class JsonApi
  def initialize u
    @url = u
    @faraday = Faraday.new(url: u)
  end
  def path r, h={}
    a = []; h.each_pair {|k,v| if v.class == Array; a << %[#{k}=#{v.join(",")}]; else a << %[#{k}=#{v}]; end }
    x = %[#{@url}/#{r}?#{a.join("&")}]
#    puts x
    return x
  end
  def [] k
    get(k)
  end
  def get r, h={}
    JSON.parse(Faraday.get(path(r,h)).body)
  end
  def post r, h={}
    JSON.parse(Faraday.post(path(r,h)).body)
  end
end

##
# Easily convert between latitude and longitude coordinates the the Maidenhead
# Locator System coordinates.
class Maidenhead
  #
  # Verify that the provided Maidenhead locator string is valid.
  #
  def self.valid_maidenhead?(location)
    return false unless location.is_a?String
    return false unless location.length >= 2
    return false unless (location.length % 2) == 0

    length = location.length / 2
    length.times do |counter|
      grid = location[counter * 2, 2]
      if (counter == 0)
        return false unless grid =~ /[a-rA-R]{2}/
      elsif (counter % 2) == 0
        return false unless grid =~ /[a-xA-X]{2}/
      else
        return false unless grid =~ /[0-9]{2}/
      end
    end

    true
  end
  def self.to_latlon(location)
    maidenhead = Maidenhead.new
    maidenhead.locator = location
    [ maidenhead.lat, maidenhead.lon ]
  end
  def locator=(location)
    unless Maidenhead.valid_maidenhead?(location)
      raise ArgumentError.new("Location is not a valid Maidenhead Locator System string")
    end
    @locator = location
    @lat = -90.0
    @lon = -180.0
    pad_locator
    convert_part_to_latlon(0, 1)
    convert_part_to_latlon(1, 10)
    convert_part_to_latlon(2, 10 * 24)
    convert_part_to_latlon(3, 10 * 24 * 10)
    convert_part_to_latlon(4, 10 * 24 * 10 * 24)
  end
  def self.to_maidenhead(lat, lon, precision = 5)
    maidenhead = Maidenhead.new
    maidenhead.lat = lat
    maidenhead.lon = lon
    maidenhead.precision = precision
    maidenhead.locator
  end
  def lat=(pos)
    @lat = range_check("lat", 90.0, pos)
  end
  def lat
    @lat.round(6)
  end
  def lon=(pos)
    @lon = range_check("lon", 180.0, pos)
  end
  def lon
    @lon.round(6)
  end
  def precision=(value)
    @precision = value
  end
  def precision
    @precision
  end
  def locator
    @locator = ''
    @lat_tmp = @lat + 90.0
    @lon_tmp = @lon + 180.0
    @precision_tmp = @precision
    calculate_field
    calculate_values
    @locator
  end

  private

  def pad_locator
    length = @locator.length / 2
    while (length < 5)
      if (length % 2) == 1
        @locator += '55'
      else
        @locator += 'LL'
      end
      length = @locator.length / 2
    end
  end
  def convert_part_to_latlon(counter, divisor)
    grid_lon = @locator[counter * 2, 1]
    grid_lat = @locator[counter * 2 + 1, 1]
    @lat += l2n(grid_lat) * 10.0 / divisor
    @lon += l2n(grid_lon) * 20.0 / divisor
  end
  def calculate_field
    @lat_tmp = (@lat_tmp / 10) + 0.0000001
    @lon_tmp = (@lon_tmp / 20) + 0.0000001
    @locator += n2l(@lon_tmp.floor).upcase + n2l(@lat_tmp.floor).upcase
    @precision_tmp -= 1
  end
  def compute_locator(counter, divisor)
    @lat_tmp = (@lat_tmp - @lat_tmp.floor) * divisor
    @lon_tmp = (@lon_tmp - @lon_tmp.floor) * divisor
    if (counter % 2) == 0
      @locator += "#{@lon_tmp.floor}#{@lat_tmp.floor}"
    else
      @locator += n2l(@lon_tmp.floor) + n2l(@lat_tmp.floor)
    end
  end
  def calculate_values
    @precision_tmp.times do |counter|
      if (counter % 2) == 0
        compute_locator(counter, 10)
      else
        compute_locator(counter, 24)
      end
    end
  end
  def l2n(letter)
    if letter =~ /[0-9]+/
      letter.to_i
    else
      letter.downcase.ord - 97
    end
  end
  def n2l(number)
    (number + 97).chr
  end
  def range_check(target, range, pos)
    pos = pos.to_f
    if pos < -range or pos > range
      raise ArgumentError.new("#{target} must be between -#{range} and +#{range}")
    end
    pos
  end
end

class DB
  def initialize(*k);
    @constructor = [k].flatten
    @ev = {}
    @id = [@constructor].flatten.join('-');
    @type = @constructor.shift
    @index = @constructor.join('-')
    @db = PStore.new(%[db/#{@id}.pstore]);
    @c = C.new(@id)
    @sub = {}
  end
  
  def id; @id; end;
  def type; @type; end;
  def index; @index; end
  
  # classift input by labels in the :is hash
  def label(i);
    ex = [];
    {}.merge(to_h[:is].to_h).each_pair {|k,v|
      ex << { text: k, label: v }
    };
    @c.classify(ex,i)[0];
  end

  def embed *e
    @c.embed(e)
  end

  def state
    c = [];
    [:host,:chan].each { |e| c << get(e)[:corpus] }
    @db.transaction { |db| db[:corpus] ||= []; c << db[:corpus] }
    c.flatten!
    { my: to_h, our: get(:chan).to_h, the: get(:host).to_h, corpus: c.compact };
  end
  
  def face q
    @c.ask(q,state)
  end

  def embed *v
    @c.embed v
  end

  def openai
    @c.openai
  end
  
  # pass input to the llms
  def ask(q);
    @c.generate(%[#{face(q)}], state)
  end
  
  # return k: v pairs
  def peek *a
    uu = to_h
    if a[0]
      aa = [a].flatten;
    else
      aa = uu.keys
    end
    o = [ %[--[#{uu.delete(:nick)}]] ]
    aa.each {|ee| if "#{uu[ee]}".length > 0; o << %[#{ee}: #{uu[ee]}]; end }
    return o.join("\n")
  end
  # incr / decr by :num
  def tick(k,h={num: 1}); @db.transaction { |db| x = db[k.to_sym].to_i; db[k.to_sym] = x + h[:num] }; end
  # push i to list
  def add(l,i,*u);
    @db.transaction {|db|
      db[l] ||= [];
      [i].flatten.each { |e| db[l] << i; }
      if u[0] == :uniq;
        db[l].uniq!;
      end
    };
  end

  def sub(k)
    add(:subs, k, :uniq)
    Z4[k, @index]
  end

  def cal
    Reminder.new(@index)
  end
  
  # bulk set k: v pairs
  def merge(h={}); @db.transaction { |db| h.each_pair { |k,v| db[k] ||= v }}; end
  # db events
  def on(k, h={}, &b); if block_given?; @ev[k] = b; else; @db.transaction { |db| @ev[k.to_sym].call(db, h) }; end; end
  # getter
  def [](k); @db.transaction { |db| db[k] }; end
  # setter
  def []=(k,v); @db.transaction { |db| db[k]=v }; end
  # transaction wrapper
  def transaction(&b); @db.transaction { |db| b.call(db) }; end
  # defined keys
  def keys; @db.transaction { |db| db.keys }; end
  # bulk output
  def to_h;
    h= {};
    @db.transaction { |db| db.keys.each { |e| h[e] = db[e]; } };
    return h;
  end
  private
  # get remote object from local.
  def get(k); Z4[k, to_h[k]]; end
end

# web ui
class APP < Sinatra::Base
  configure do
    set :port, 4567
    set :bind, '0.0.0.0'
    set :public_dir, 'public/'
    set :views, 'views/'
  end
  # handle dumb shit
  ['favicon.ico'].each { |e| get("/#{e}") {}}
  # index
  get('/') {
    @db = { host: Z4[:host, request.host] }
    erb :index
  }
  # routes
  get('/:view') {
    @db = { host: Z4[:host, request.host] }
    [:user, :chan, :net, :dev].each { |e| if params.has_key?(e); @db[e.to_sym] = Z4[e.to_sym, params[e]]; end  }
    erb params[:view].to_sym
  }
  # /object/item -> json
  get('/:o/:i') {
    content_type "application/json"
    JSON.generate(Z4[params[:o].to_sym, params[:i]].to_h)
  }
  # handle post
  post('/') {
    @db = { host: Z4[:host, request.host] }
    [:user, :chan, :net, :dev].each { |e| if params.has_key?(e); @db[e.to_sym] = Z4[e.to_sym, params[e]]; end  }
    content_type = 'application/json'
    # set grid
    hh = {}
    
    if params.has_key?(:lat) && params.has_key?(:lon)
      @db[:user][:lat] = params[:lat]
      @db[:user][:lon] = params[:lon]
      @db[:user][:grid] = Z4.to_grid(params[:lat],params[:lon])
      @db[:grid] = Z4[:grid, @db[:user][:grid]]
      hh[:locator] = @db[:user][:grid]
    end
    
    @db.each_pair { |k,v| hh[k] = v.to_h }
    return JSON.generate(hh)
  }
end

# the bot
module BOT
  @@BOT = Discordrb::Commands::CommandBot.new token: ENV['Z4_DISCORD_TOKEN'], prefix: '#'
  @@BOT_CMD = {}
  @@BOT_INP = {}
  @@BOT_FIL = {}
  @@BOT_RES = {}
  # fields for ui
  @@FIELDS = { discord: 'passport_control', phone: 'telephone', social: 'star2', store: 'convenience_store',
               tips: 'moneybag', embed: 'information_source', img: 'frame_photo' }
  # standard fields for #i interface & contactor
  @@KEYS = {
    user: [ :name, :age, :city, :since, :lvl, :xp, :gp, :job, :team, :union, :wins, :losses, :points, :turns, :played ],
    chan: [ :desc, :city, :since, :wins, :losses, :points, :turns, :played ],
    host: [ :desc ]
  };
  
  def self.client
    @@BOT
  end
  def self.keys
    @@KEYS
  end
  def self.fields
    @@FIELDS
  end
  # only for joining bot to a server!
  def self.invite_url
    @@BOT.invite_url
  end
  # create a bot command
  def self.command(n, h={}, &b)
    @@BOT_CMD[n] = [h, b]
  end
  # create a regex input handler.
  def self.message(r, h={}, &b)
    @@BOT_INP[r] = [h, b]
  end
  # create a regex input mask to handle learning.
  def self.filter(r, h={}, &b)
    @@BOT_FIL[r] = [h, b]
  end
  # create a regex input mask for pre-defined responses.
  def self.response(r, h={}, &b)
    @@BOT_RES[r] = [h, b]
  end
  # extract date & time for better learning of events
  def self.calendar *i
    tt = false
    w = []
    ts = {}
    # process time/date
    [i].flatten.each { |ee|
      if m = /(\d\d\d\d)\/(\d\d)\/(\d\d)/.match(ee);
        ts[:year] = m[1]
        ts[:month] = m[2]
        ts[:day] = m[3]
        tt = true
      elsif m = /(\d+):(\d\d)([+-]\d+)?/.match(ee)
        ts[:hour] = m[1]
        ts[:minute] = m[2]
        ts[:tz] = m[3] || Time.now.utc_offset
        tt = true
      else;
        w << ee;
      end
    }
    
    # marshal timestamp
    if !ts.has_key?(:year); ts[:year] = Time.now.year; end
    if !ts.has_key?(:month); ts[:month] = Time.now.month; end
    if !ts.has_key?(:day); ts[:day] = Time.now.day; end
    if !ts.has_key?(:hour); ts[:hour] = 0; end
    if !ts.has_key?(:minute); ts[:minute] = 0; end
    if !ts.has_key?(:tz); ts[:tz] = Time.now.utc_offset; end
    #puts "[time] #{ts}"
    # generate timestamp
    now = Time.now
    time = Time.new(ts[:year],ts[:month],ts[:day],ts[:hour],ts[:minute],0,ts[:tz])
    ts = time.strftime('%m/%d/%YT%H:%M')
    # return message
    if tt == true
      if time.to_i > now.to_i
        return %[#{w.join(" ").downcase} is on #{ts}]
      end
    else
      return %[#{w.join(" ").downcase}]
    end
  end
  # handle bot event.
  def self.event e
    if e.server
      d = %[#{e.server.id}]
    else
      d = %[#{e.channel.id}]
    end
    # private message?
    if e.channel.name == e.user.name
      pm = true
    else
      pm = false
    end
    # process message as [cmd] msg
    t = "#{e.message.text}"
    w = t.split(" ")
    if /^#.+/.match(w[0])
      cmd = w.shift
      msg = w.join(" ").gsub(/<.*>/, '').gsub("  ", " ").gsub("   ", " ").gsub(/^ /, "")
    else
      msg = t.gsub(/<.*>/, '').gsub("  ", " ").gsub("   ", " ").gsub(/^ /, "")
    end
    # extract user mentions.
    us = []
    if e.message.mentions.length > 0
      e.message.mentions.each {|ee| us << "#{ee.id}" }
    end
    # extract role mentions.
    ro = []
    if e.message.role_mentions.length > 0
      e.message.role_mentions.each {|ee| ro << ee.name }
    end
    pv = []
    lvl = 0
    # update lvl by role.
    if e.author.roles.length > 0
      e.author.roles.each { |ee|
        {
          operator: 5,
          agent: 4,
          manager: 4,
          ambassador: 3,
          influencer: 2,
          character: 1,
          bartender: 1,
          door: 1,
          floor: 1
        }.each_pair { |k,v|
        if ee.name == k.to_s && lvl < v
          lvl = v
        end
        }
        pv << %[#{ee.name}]
      }
    end
    # return event hash
    h = {
      lvl: lvl,
      db: d,
      server: d,
      pm: pm,
      cmd: cmd,
      msg: msg,
      words: w,
      user: "#{e.user.id}",
      nick: "#{e.user.name}",
      chan: "#{e.channel.id}",
      channel: "#{e.channel.name}",
      users: us,
      roles: ro,
      priv: pv
    }
    puts "[EVENT] #{h}"
    return h
  end
  # start bot
  def self.init!
    # handle commands
    @@BOT_CMD.each_pair do |k,v|
      @@BOT.command(k,v[0],&v[1])
    end
    # handle conversation
    @@BOT.message() do |e|
      h = BOT.event(e)
      u = Z4[:user, h[:user]]
      u[:chan] = h[:chan]
      u[:lvl] = h[:lvl]
      if h[:cmd] == nil
        # is question?
        if /^.*\?$/.match(h[:msg])
          # output question
          e.respond(u.ask(h[:msg]))
        else
          t_start = Time.now.to_f
          o = []
          # imply messages from regex &block
          @@BOT_INP.each_pair { |r,b|
            if m = r.match(h[:msg]);
              o << b[1].call(e, m, h, u, b[0]);
            end
          }
          # filter what goes into the corpus by regex &block
          @@BOT_FIL.each_pair { |r,b|
            if m = r.match(h[:msg]);
              [b[1].call(e, m, h, u, b[0])].flatten.each { |e| u.add(:info, e); }
            end
          }
          # construct response by regex &block
          @@BOT_RES.each_pair { |r,b|
            if m = r.match(h[:msg]);
              [b[1].call(e, m, h, u, b[0])].each_with_index { |e| o << u.ask(e); }
            end
          }
          # output response
          o << %[ok: #{Time.now.to_f - t_start} seconds.]
          e.respond(o.flatten.join("\n"))
        end
      end
    end
    # GO!
    @@BOT.run
  end
end

# introspection & user settings & mention peek
BOT.command(:'i', usage: "#my [<key> <value>] [@user...]", description: "Use this.") do |e|
  o = [%[--[[NODE]] #{ENV['COHORT']}/#{ENV['NODE']}]]
  h = BOT.event(e)
  u = Z4[:user, h[:user]]
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  if "#{h[:msg]}".length > 0
    # set k: v
    k = h[:words].shift; v = h[:words].join(" ");
    if !['gp','lvl','xp'].include?(k); u[k.to_sym] = v; end
  else
    # peek other users
    if h[:users].length > 0
      h[:users].each { |e| o << Z4[:user, e].peek(BOT.fields[:user]) }
    end
  end
  # clickables
  oo = ["--[YOU] "]
  BOT.fields.each_pair {|k,v| if "#{u[k]}".length > 0; oo << %[:#{v}:]; end }
  o << oo.join(' ')

  # settables / earnables
  o << u.peek(BOT.keys[:user])

  # collectables
  [:badges].each do |e|
    o << %[--[#{e}]]
    u.sub(e).to_h.each_pair { |k,v| o << %[#{k}: #{v}] }
  end

  # usables
  [:inventory].each do |e|
    oo = []
    u.sub(e).to_h.each_pair { |k,v| oo << %[#{k}] }
    o << %[--[#{e}] #{oo.join(", ")}]
  end
  
  # navagator
  o << %[--[NAVAGATOR] https://#{u[:host]}/menu?user=#{h[:user]}&chan=#{h[:chan]}]
  e.respond(%[#{o.join("\n")}])
end

BOT.command(:plan, usage: "#reminders", description: "Display your plan.") do |e|
  o = []
  h = BOT.event(e)
  u = Z4[:user, h[:user]]
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  if h[:words].length > 0
    k,v = h[:msg].split(": ")
    u.cal[k] = v
  else
    o << u.cal.schedule
  end
  e.respond(o.join("\n"))
end

# chan / host settings and introspection
BOT.command(:set, usage: "#set <obj> <key> <value>", description: "Use this tool to update system settings.") do |e|
  o = []
  t = h[:words].shift.to_sym;
  h = BOT.event(e)
  u = Z4[:user, h[:user]]
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  if u[:lvl] >= 3 
    x = Z4[t, u[t]]
    if h[:words].length > 0
      k = h[:words].shift; v = h[:words].join(" "); x[k.to_sym] = v
    end
  end
  oo = ["--[#{t.upcase}] "]
  BOT.fields.each_pair {|k,v| if "#{x[k]}".length > 0; oo << %[:#{v}:]; end }
  o << oo.join(' ')
  o << x.peek(BOT.keys[t])
  e.respond(%[#{o.join("\n")}])
end

# gp payment management
BOT.command(:gp, usage: "#gp <amt> @user...", description: "Use this tool to give other users gp.") do |e|
  h = BOT.event(e)
  amt = h[:words].shift.to_f
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  [h[:users]].flatten.each { |e|
    uu = Z4[:user, e];
    uu.tick(:gp, amt);
    u.tick(:gp, (0 - amt));
  }
  e.respond(%[You gp #{amt}gp to #{h[:users].join(", ")}.])
end

# xp reward management
BOT.command(:xp, usage: "#xp <amt> @user...", description: "Use this tool to give other users xp.") do |e|
  h = BOT.event(e)
  amt = h[:words].shift.to_f
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  [h[:users]].flatten.each { |e|
    uu = Z4[:user, e];
    uu.tick(:xp, amt);
    u.tick(:xp, (0 - amt));
  }
  e.respond(%[You gave #{amt}xp to #{h[:users].join(", ")}.])
end

# clone item for users
BOT.command(:give, usage: "#item <item> @user...", description: "Use this tool to give items to other users.") do |e|
  h = BOT.event(e)
  i = h[:words].shift
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  [h[:users]].flatten.each { |e|
    uu = Z4[:user, e];
    uu.sub(:inventory)[i] = u.sub(:inventory)[i]
  }
  e.respond(%[You gave #{i} to #{h[:users].join(", ")}.])
end

# create new items
BOT.command(:make, usage: "#make <item> <desc>", description: "Use this tool to give items to other users.") do |e|
  h = BOT.event(e)
  k = h[:words].shift
  v = h[:words].join(' ')
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  u.sub(:inventory)[k] = v
  e.respond(%[made.])
end

# use item to produce outputs
BOT.command(:use, usage: "#use <item> <arguments>", description: "Use this tool to use available items") do |e|
  h = BOT.event(e)
  k = h[:words].shift
  v = h[:words].join(' ')
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  if "#{u.sub(:inventory)[k]}".length > 0
    e.respond(ERB.new(u.sub(:inventory)[k]).result(binding))
  else
    e.respond(%[You do not have #{k}])
  end
end

# certification system
BOT.command(:badge, usage: "#badge <badge> @user...", description: "Use this tool to give badges to other users.") do |e|
  h = BOT.event(e)
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  puts %[BADGE: |#{h[:msg]}|]
  if u.sub(:badges)[h[:msg].strip] > 0
    [h[:users]].flatten.each { |e|
      uu = Z4[:user, e];
      x = uu.sub(:badges)[h[:msg].strip].to_i
      uu.sub(:badges)[h[:msg].strip] = x + 1 
    }
    e.respond(%[awarded.])
  else
    e.respond(%[You can't give a badge you don't have.]);
  end
end

# list managment
BOT.command(:add, usage: "#add <list> <item>", description: "Use this tool to add items to the appropriate list.") do |e|
  h = BOT.event(e)
  k = h[:words].shift.to_sym
  v = h[:words].join(" ")
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  if "#{v}".length > 0
    u.add(k,BOT.calendar(h[:words]))
  end
  e.respond("#{k}: #{u[k]}");
end

# chan / host list managment
BOT.command(:op, usage: "#op <obj> <list> <item>", description: "Used for operation.") do |e|
  h = BOT.event(e)
  t = h[:words].shift.to_sym
  k = h[:words].shift.to_sym
  v = h[:words].join(" ")
  u = Z4[:user, h[:user]];
  [ :chan, :channel, :nick, :lvl ].each { |e| u[e] = h[e] }
  x = Z4[t, u[t]]
  if "#{v}".length > 0
    x.add(k,BOT.calendar(h[:words]))
  end
  e.respond("#{t}[#{k}]: #{x[k]}");
end

# example input mask handler.
BOT.message(/Hello, (.+)!/) do |e, m, h, user, opts|
  if m[1] != 'zyphr'
    o = %[#{m[1]} isn't my name.]
  else
    o = %[Hi.]
  end
  #  e.respond(o)
  o
end

# example response macro.
BOT.response(/Score/) do |e, m, h, user, opts|
  [
    %[what time is it?],
    %[What events are today?],
    %[How long before my next event?]
  ]
end

# generic bluetooth wrapper
module BT
  def self.pair *d
    `bluetoothctl -- pair #{d[0] || ENV['BT']}`.chomp
  end
  def self.trust *d
    `bluetoothctl -- trust #{d[0] || ENV['BT']}`.chomp
  end
  def self.connect *d
    `bluetoothctl -- connect #{d[0] || ENV['BT']}`.chomp
  end
  def self.disconnect *d
    `bluetoothctl -- disconnect #{d[0] || ENV['BT']}`.chomp
  end
  def self.available
    `bluetoothctl -- devices`.chomp
  end
  def self.paired
    `bluetoothctl -- paired-devices`.chomp
  end
end

##
# the Z4 module
#
#
#
module Z4;
  @@VLC = VLC::Client.new('127.0.0.1', 9595)
  @@VLC.connect
  Dir['media/*'].each { |e| @@VLC.add_to_playlist(e) }
  def self.media *play
    if play.length > 0
      [play].flatten.each { |e| @@VLC.add_to_playlist(e) }
    end
    @@VLC
  end
  
  @@INFO = Hash.new do |h,k|
    a = []
    s = Wikipedia.find(k.to_s)
    if s
      s.page['extract'].split("\n").each { |e|
        ee = %[#{e}]
        if !/^=+/.match(e)
          ee.split(". ").each { |ss|
            if ss.length > 3 && ss.length <= 200;
              a << ss
            end
          }
        end
      }
      h[k] = a
    else
      return false
    end
  end
  
  def self.corpus
    @@INFO
  end
  
  @@HERE = Hash.new do |h,k|
    exist = false
    x = Wikipedia.find(k.to_s)
    if x
      xx = x.coordinates
      if xx[0]
        g = Z4.to_grid(xx[0],xx[1])
        h[k] = {
          here: k.to_s,
          lat: xx[0],
          lon: xx[1],
          grid: g,
          square: Z4[:grid, g],
          info: @@INFO[k],
          weather: Z4.weather('forecast',
                              latitude: xx[0],
                              longitude: xx[1],
                              current: [:temperature_2m,
                                        :relativehumidity_2m,
                                        :precipitation,
                                        :weathercode,
                                        :surface_pressure,
                                        :windspeed_10m,
                                        :winddirection_10m,
                                        :windgusts_10m],
                              minutely_15: [:temperature_2m,
                                            :relativehumidity_2m,
                                            :precipitation,
                                            :weathercode,
                                            :windspeed_10m,
                                            :windgusts_10m,
                                            :visibility,
                                            :lightning_potential],
                              hourly: [:temperature_2m,
                                       :precipitation_probability,
                                       :precipitation,
                                       :weathercode,
                                       :surface_pressure,
                                       :visibility],
                              daily: [:weathercode,
                                      :temperature_2m_max,
                                      :temperature_2m_min,
                                      :precipitation_sum,
                                      :precipitation_hours,
                                      :precipitation_probability_max,
                                      :windspeed_10m_max,
                                      :windgusts_10m_max,
                                      :winddirection_10m_dominant]
                             )
        }
      else
        return false
      end
    else
      return false
    end
  end
  def self.here
    @@HERE
  end
  def self.weather r, h={}
    h[:timezone] = %[America%2FDenver]
    h[:precipitation_unit] = %[inch]
    h[:forecast_days] = 3
    h[:windspeed_unit] = %[mph]
    h[:temperature_unit] = %[fahrenheit]
    JsonApi.new("https://api.open-meteo.com/v1").get(r,h)
  end
  
  # gps -> gridsquare
  def self.to_grid(lat,lon)
    Maidenhead.to_maidenhead(lat,lon,10)
  end
  # gridsquare -> gps
  def self.to_gps(m)
    Maidenhead.to_latlon(m)
  end

  def self.bt
    BT
  end
  # database hook
  def self.[] *k
    DB.new(k)
  end
end

# load external libraries
Dir['lib/pryon/*'].each {|e|
  if !/^.*~$/.match(e)
    f = e.gsub('lib/', '').gsub('.rb', '');
    require_relative(f)
  end
}

# eneric object hooks.
@host = Hash.new { |h,k| h[k] = Z4[:host, k] }
@chan = Hash.new { |h,k| h[k] = Z4[:chan, k] }
@user = Hash.new { |h,k| h[k] = Z4[:user, k] }
@game = Hash.new { |h,k| h[k] = Z4[:game, k] }


# load runtime
if ARGF.argv[0]
  load ARGF.argv[0]
else
  load 'pryon.rb'
end

# load host fixed calendars
Dir['calendars/*.txt'].each { |e|
  key = e.gsub('calendars/','').gsub('.txt','').to_sym
  puts "[CALENDAR] #{key}"
  file = File.read(e)
  file.split("\n").each {|line|
    @host.each_pair { |k,v|
      puts %[[CALENDAR] #{key} => #{line}];
      v.add(key, line, :uniq);
    }
  }
}

# Z4 Processes
@procs = {}

# begin processes
@procs[:bot] = Process.detach(fork { BOT.init! })
@procs[:app] = Process.detach(fork { APP.run!  })

# handle exit.
def do_exit
  @procs.each_pair { |k,v| Process.kill('INT', v); Process.wait; @procs.delete(k); }
  puts "[ZEEFOUR] BYE";
  Process.exit!
end

# trap interrupts
['INT', 'TERM', 'EXIT'].each { |e| trap(e) { puts "[ZEEFOUR] #{e}"; do_exit; } }


