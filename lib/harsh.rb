# Harsh

module ::Haml
  module Filters
    module Harsh
      def initialize(text)
        @text = highlight_text(text)
      end
      def highlight_text(text, opts = ::Harsh::DEFAULT_OPTIONS)
        Uv.parse( text, "xhtml", opts[:format], opts[:lines], opts[:theme])
      end
      def parse_opts(text)
        opts = {}
        all_lines = text.split(/\n/)
        return [opts, text] unless all_lines.first =~ /#!harsh/
        
        line = all_lines.first
        opts[:format] = $1 if line =~ /syntax\s*=\s*([\w-]+)/
        opts[:theme]  = $1 if line =~ /theme\s*=\s*([\w-]+)/
        opts[:lines]  = (line =~ /lines\s*=\s*(\w+)/) ? ($1 == 'true') : false
        
        [opts, all_lines[1..-1].join("\n")]
      end
      
      def render(text)
        opts, text = parse_opts(text)
        Haml::Helpers.preserve(highlight_text(text.rstrip, ::Harsh::DEFAULT_OPTIONS.merge(opts)))
      end
    end
  end
end
  
module Harsh
  module ErbMethods
    def syntax_highlight(*args, &block)
      require 'uv' unless defined? Uv
      opts, text = Harsh::parse_args(args)
      if block_given?
        text = capture(&block)
        text = text.sub(/\n/,"") if text =~ /^(\s*)\n/
      end
      Uv.parse( text, "xhtml", opts[:format].to_s, opts[:lines], opts[:theme].to_s)
    end
    alias_method :harsh, :syntax_highlight
    
    def prettify(text)
      text_pieces = text.split(/(<pre>\s*<code>\s*\[\w+\]|<pre>\s*<code>\s*|<\/code>\s*<\/pre>)/)
      in_pre = false
      language = nil
      text_pieces.collect do |piece|
        if piece =~ /^<pre>\s*<code>\s*(\[(\w+)\])?$/
          language = $2
          in_pre = true
          nil
        elsif piece =~ /^<\/code>\s*<\/pre>/
          in_pre = false
          nil
        elsif in_pre
          lang = language ? language : :ruby
          harsh :format => lang do
            CGI::unescapeHTML(piece)
          end
        else
          piece
        end
      end
    end      
    
    def markdown(text)
      prettify (defined?(RDiscount) ? RDiscount : BlueCloth).new(text).to_html
    end
    
    def textilize(text)
      prettify RedCloth.new(text).to_html
    end
  end
  
  class << self
    def enable_haml
      ::Haml::Filters::Harsh.send(:include, Haml::Filters::Base)
      ::Haml::Filters::Harsh.module_eval do
        lazy_require 'uv'
      end
    end
    
    def defaults(settings={})
      settings.each do |k, v|
        Harsh::DEFAULT_OPTIONS[k] = v
      end
    end
  end
  
  private
  
  DEFAULT_OPTIONS = {:format => "ruby", :theme => "twilight", :lines => false}
  
  def self.parse_args(args)
    return DEFAULT_OPTIONS if args.empty?
    
    text = args.first.is_a?(String) ? args.first : nil
    opts = args.last.is_a?(String) ? DEFAULT_OPTIONS : DEFAULT_OPTIONS.merge(args.last)
    text = text.sub(/\n/,"") if text =~ /^(\s*)\n/
    
    [opts, text]
  end
end