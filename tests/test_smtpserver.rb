require 'em_test_helper'
require 'net/smtp'
require 'time'

class TestSmtpServer < Test::Unit::TestCase

  # Don't test on port 25. It requires superuser and there's probably
  # a mail server already running there anyway.
  Localhost = "127.0.0.1"
  Localport = 25001

  # This class is an example of what you need to write in order
  # to implement a mail server. You override the methods you are
  # interested in. Some, but not all, of these are illustrated here.
  #
  class Mailserver < EM::Protocols::SmtpServer

    attr_reader :my_msg_body, :my_sender, :my_recipients

    def initialize *args
      super
    end
    def receive_sender sender
      @my_sender = sender
      #p sender
      true
    end
    def receive_recipient rcpt
      @my_recipients ||= []
      @my_recipients << rcpt
      true
    end
    def receive_data_chunk c
      @my_msg_body = c.last
    end
  end

  def test_mail
    c = nil
    EM.run {
      EM.start_server( Localhost, Localport, Mailserver ) {|conn| c = conn}
      client = EM::Protocols::SmtpClient.send :host=>Localhost,
        :port=>Localport,
        :domain=>"bogus",
        :from=>"me@example.com",
        :to=>"you@example.com",
        :header=> {"Subject"=>"Email subject line", "Reply-to"=>"me@example.com"},
        :body=>"Not much of interest here."

      client.callback { EM.stop }

      EM::Timer.new(2) { EM.stop } # prevent hanging the test suite in case of error
    }
    assert_equal( "Not much of interest here.", c.my_msg_body )
    assert_equal( "<me@example.com>", c.my_sender )
    assert_equal( ["<you@example.com>"], c.my_recipients )
  end

  def test_with_net_smtp
    c = nil
    EM.run do
      EM.start_server( Localhost, Localport, Mailserver ) {|conn| c = conn}
      operation = proc do
        Net::SMTP.start(Localhost, Localport, "bogus") do |smtp|
          send_smtp_message(smtp, 'me@example.com', 'you@example.com')
          send_smtp_message(smtp, 'me@example.com', 'you@example.com')
        end

        assert_equal( "Not much of interest here.", c.my_msg_body )
        assert_equal( "<me@example.com>", c.my_sender )
        assert_equal( ["<you@example.com>", "<you@example.com>"], c.my_recipients )
      end

      callback = proc do |result|
        EM.stop
      end

      EM.defer(operation, callback)
    end
  end

private

  def send_smtp_message(smtp, from, to)
    msg = %{From: #{from}
To: #{to}
Subject: Email subject line
Date: #{Time.now.rfc2822}
Message-Id: <#{Time.now.to_f}@example.com>

Not much of interest here.
}
    smtp.send_message(msg, from, to)
  end
end
