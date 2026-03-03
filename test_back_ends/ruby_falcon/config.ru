#!/usr/bin/env ruby
# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'protocol/http/body/buffered'
require 'pg'
require 'oj'
require 'set'

DB_HOST = ENV.fetch('DB_HOST', 'postgres')

# ── Database pool (simple) ─────────────────────────────────────────────
module DB
  @pool = []
  @mutex = Mutex.new

  def self.connect
    30.times do |i|
      conn = PG.connect(host: DB_HOST, port: 5432, dbname: 'bench',
                         user: 'bench', password: 'bench')
      @pool << conn
      return if @pool.size >= 16
    rescue PG::ConnectionBad => e
      puts "DB not ready (#{i + 1}/30): #{e.message}"
      sleep 1
    end
    16.times do
      @pool << PG.connect(host: DB_HOST, port: 5432, dbname: 'bench',
                           user: 'bench', password: 'bench')
    end
  rescue StandardError => e
    abort "Failed to connect to DB: #{e.message}"
  end

  def self.acquire
    @mutex.synchronize do
      @pool.pop
    end
  end

  def self.release(conn)
    @mutex.synchronize do
      @pool.push(conn)
    end
  end
end

# ── WebSocket Hub ──────────────────────────────────────────────────────
module WsHub
  @clients = Set.new
  @mutex = Mutex.new

  def self.add(ws)    = @mutex.synchronize { @clients.add(ws) }
  def self.remove(ws) = @mutex.synchronize { @clients.delete(ws) }

  def self.broadcast(msg)
    @mutex.synchronize do
      @clients.each do |ws|
        ws.write(msg) rescue nil
        ws.flush rescue nil
      end
    end
  end
end

# ── Rack app ───────────────────────────────────────────────────────────
class BenchmarkApp
  def call(env)
    method = env['REQUEST_METHOD']
    path = env['PATH_INFO']

    case [method, path]
    when ['POST', '/items']
      handle_post(env)
    when ->(mp) { mp[0] == 'GET' && mp[1]&.start_with?('/items/') }
      handle_get(env, path)
    else
      [404, { 'content-type' => 'application/json' }, ['{"error":"not found"}']]
    end
  end

  private

  def handle_post(env)
    body = env['rack.input'].read
    json = Oj.load(body)
    name = json['name']
    value = json['value'] || ''

    unless name
      return [400, { 'content-type' => 'application/json' }, ['{"error":"missing name"}']]
    end

    conn = DB.acquire
    begin
      result = conn.exec_params(
        'INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value',
        [name, value]
      )
      row = result.first
      resp = Oj.dump({ id: row['id'].to_i, name: row['name'], value: row['value'] })
      [201, { 'content-type' => 'application/json' }, [resp]]
    ensure
      DB.release(conn)
    end
  end

  def handle_get(env, path)
    id = path.sub('/items/', '').to_i
    conn = DB.acquire
    begin
      result = conn.exec_params(
        'SELECT id, name, value FROM items WHERE id=$1', [id]
      )
      if result.ntuples.zero?
        [404, { 'content-type' => 'application/json' }, ['{"error":"not found"}']]
      else
        row = result.first
        resp = Oj.dump({ id: row['id'].to_i, name: row['name'], value: row['value'] })
        [200, { 'content-type' => 'application/json' }, [resp]]
      end
    ensure
      DB.release(conn)
    end
  end
end

# Initialize DB
DB.connect
puts "Ruby/Falcon server starting on :8080"

run BenchmarkApp.new
