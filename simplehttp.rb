require 'bundler'
Bundler.require :default

require 'socket'

class SimpleHttp < EventMachine::Connection
  def initialize options={}
    @path = options[:path]
    @port = options[:port]
  end

  def post_init
    @buffer = BufferedTokenizer.new "\r\n"
    @lines = []
    @remote_port, @remote_ip = Socket.unpack_sockaddr_in get_peername 
  end

  def receive_data data
    @buffer.extract(data).each do |line|
      receive_line line
    end
  end

  def receive_line line
    unless line.empty?
      @lines << line
    else
      receive_request @lines
      @lines.clear
    end
  end

  def receive_request request
    action, page, protocol = request.shift.split ' ', 3
    headers = {}
    request.each do |line|
      header = line.split /: */, 2
      headers[header[0]] = header[1] if header.length == 2
    end
  end

  def send_line line=nil
    send_data "#{line}\r\n"
  end
end

port = (ARGV.shift || 8080).to_i
path = File.expand_path(ARGV.shift || '.')

EventMachine.run do
  EventMachine.start_server '0.0.0.0', port, SimpleHttp, :path => path, :port => port
end
