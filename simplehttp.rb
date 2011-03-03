require 'bundler'
Bundler.require :default

require 'cgi'
require 'socket'
require 'uri'

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

    if action.casecmp('GET').zero?
      get page, headers
    else
      error 'NOT_IMPLEMENTED'
    end
  end

  def error key
    send_line "HTTP/1.0 #{CGI::HTTP_STATUS[key]}"
    send_line "Content-Type: text/plain"
    send_line "Content-Length: #{CGI::HTTP_STATUS[key].length}"
    send_line
    send_data CGI::HTTP_STATUS[key]
    close_connection_after_writing
  end

  def get resource, headers
    uri = URI.parse resource
    return error('BAD_REQUEST') unless uri.start_with? '/'
    return error('BAD_REQUEST') if uri.path.include? '/.'
    file = File.expand_path File.join(@path, uri.path)
    if File.file? file
      send_line 'HTTP/1.0 200 OK'
      send_line "Content-Length: #{File.size? file}"
      send_line
      if File.size? file
        stream_file_data(file).callback do
          close_connection_after_writing
        end
      else
        close_connection_after_writing
      end
    else
      error 'NOT_FOUND'
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
