require 'bundler'
Bundler.require :default

require 'socket'

class SimpleHttp < EventMachine::Connection
  def initialize options={}
    @path = options[:path]
    @port = options[:port]
  end

  def post_init
    @remote_port, @remote_ip = Socket.unpack_sockaddr_in get_peername 
  end
end

port = (ARGV.shift || 8080).to_i
path = File.expand_path(ARGV.shift || '.')

EventMachine.run do
  EventMachine.start_server '0.0.0.0', port, SimpleHttp, :path => path, :port => port
end
