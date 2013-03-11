# encoding: utf-8

##
# Only load the Mail gem when using Mail notifications
Backup::Dependency.load('mail')

module Backup
  module Notifier
    class Mail < Base

      ##
      # Mail delivery method to be used by the Mail gem.
      # Supported methods:
      #
      # `:smtp` [::Mail::SMTP] (default)
      # : Settings used only by this method:
      # : `address`, `port`, `domain`, `user_name`, `password`
      # : `authentication`, `enable_starttls_auto`, `openssl_verify_mode`
      #
      # `:sendmail` [::Mail::Sendmail]
      # : Settings used only by this method:
      # : `sendmail`, `sendmail_args`
      #
      # `:exim` [::Mail::Exim]
      # : Settings used only by this method:
      # : `exim`, `exim_args`
      #
      # `:file` [::Mail::FileDelivery]
      # : Settings used only by this method:
      # : `mail_folder`
      #
      attr_accessor :delivery_method

      ##
      # Sender and Receiver email addresses
      # Examples:
      #  sender   - my.email.address@gmail.com
      #  receiver - your.email.address@gmail.com
      attr_accessor :from, :to

      ##
      # The address to use
      # Example: smtp.gmail.com
      attr_accessor :address

      ##
      # The port to connect to
      # Example: 587
      attr_accessor :port

      ##
      # Your domain (if applicable)
      # Example: mydomain.com
      attr_accessor :domain

      ##
      # Username and Password (sender email's credentials)
      # Examples:
      #  user_name - meskyanichi
      #  password  - my_secret_password
      attr_accessor :user_name, :password

      ##
      # Authentication type
      # Example: plain
      attr_accessor :authentication

      ##
      # Automatically set TLS
      # Example: true
      attr_accessor :enable_starttls_auto

      ##
      # OpenSSL Verify Mode
      # Example: none - Only use this option for a self-signed and/or wildcard certificate
      attr_accessor :openssl_verify_mode

      ##
      # When using the `:sendmail` `delivery_method` option,
      # this may be used to specify the absolute path to `sendmail` (if needed)
      # Example: '/usr/sbin/sendmail'
      attr_accessor :sendmail

      ##
      # Optional arguments to pass to `sendmail`
      # Note that this will override the defaults set by the Mail gem (currently: '-i -t')
      # So, if set here, be sure to set all the arguments you require.
      # Example: '-i -t -X/tmp/traffic.log'
      attr_accessor :sendmail_args

      ##
      # When using the `:exim` `delivery_method` option,
      # this may be used to specify the absolute path to `exim` (if needed)
      # Example: '/usr/sbin/exim'
      attr_accessor :exim

      ##
      # Optional arguments to pass to `exim`
      # Note that this will override the defaults set by the Mail gem (currently: '-i -t')
      # So, if set here, be sure to set all the arguments you require.
      # Example: '-i -t -X/tmp/traffic.log'
      attr_accessor :exim_args

      ##
      # Folder where mail will be kept when using the `:file` `delivery_method` option.
      # Default location is '$HOME/Backup/emails'
      # Example: '/tmp/test-mails'
      attr_accessor :mail_folder

      def initialize(model, &block)
        super(model)

        instance_eval(&block) if block_given?
      end

      private

      ##
      # Notify the user of the backup operation results.
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` was set to `true`
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` was set to `true`
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including the Exception which caused
      # : the failure, the Exception's backtrace, a copy of the current
      # : backup log and other information if `on_failure` was set to `true`
      #
      def notify!(status)
        name, send_log =
            case status
            when :success then [ 'Success', false ]
            when :warning then [ 'Warning', true  ]
            when :failure then [ 'Failure', true  ]
            end

        email = new_email
        email.subject = "[Backup::%s] #{@model.label} (#{@model.trigger})" % name
        email.body    = @template.result('notifier/mail/%s.erb' % status.to_s)

        if send_log
          email.convert_to_multipart
          email.attachments["#{@model.time}.#{@model.trigger}.log"] = {
            :mime_type => 'text/plain;',
            :content   => Logger.messages.join("\n")
          }
        end

        email.deliver!
      end

      ##
      # Configures the Mail gem by setting the defaults.
      # Creates and returns a new email, based on the @delivery_method used.
      def new_email
        method = %w{ smtp sendmail exim file test }.
            index(@delivery_method.to_s) ? @delivery_method.to_s : 'smtp'

        options =
            case method
            when 'smtp'
              { :address              => @address,
                :port                 => @port,
                :domain               => @domain,
                :user_name            => @user_name,
                :password             => @password,
                :authentication       => @authentication,
                :enable_starttls_auto => @enable_starttls_auto,
                :openssl_verify_mode  => @openssl_verify_mode }
            when 'sendmail'
              opts = {}
              opts.merge!(:location  => File.expand_path(@sendmail)) if @sendmail
              opts.merge!(:arguments => @sendmail_args) if @sendmail_args
              opts
            when 'exim'
              opts = {}
              opts.merge!(:location  => File.expand_path(@exim)) if @exim
              opts.merge!(:arguments => @exim_args) if @exim_args
              opts
            when 'file'
              @mail_folder ||= File.join(Config.root_path, 'emails')
              { :location => File.expand_path(@mail_folder) }
            when 'test' then {}
            end

        ::Mail.defaults do
          delivery_method method.to_sym, options
        end

        email = ::Mail.new
        email.to   = @to
        email.from = @from
        email
      end

    end
  end
end
