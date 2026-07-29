# Early Ruby 1.8 + capture native mkxp Input before Essentials overwrites it
kawariki_ruby18 = File.expand_path("~/Library/Application Support/RPGM-Launcher/kawariki/libs/ruby18.rb")
require kawariki_ruby18 if File.exist?(kawariki_ruby18)

unless Thread.respond_to?(:critical)
  class Thread
    @critical = false
    class << self
      attr_accessor :critical
    end
  end
end
Thread.critical = false if Thread.respond_to?(:critical=)

ENV["TEMP"] ||= ENV["TMPDIR"] || "/tmp"
ENV["TMP"]  ||= ENV["TEMP"]

# ---------------------------------------------------------------------------
# sprintf / format / String#% — Ruby 1.8 → 3 compatibility
#
# Classic PE/RGSS bugs under modern Ruby (mkxp-z):
#   sprintf("%02x", s[0])  # Ruby 1.8: s[0] was Fixnum byte; now String → ArgumentError
#   sprintf("%d", nil)     # TypeError
#   "%%%02x" % char        # same via String#%
#
# Strategy: try native sprintf first; on Integer conversion errors, coerce args
# (single-byte String → ord, digit String → to_i, nil → 0) and retry once.
# Successful paths (%s, normal numbers) are unchanged.
# ---------------------------------------------------------------------------
module TGSprintfCompat
  module_function

  def coerce_arg(arg)
    case arg
    when nil
      0
    when String
      if arg.bytesize == 1
        arg.ord
      elsif arg.match?(/\A[+-]?\d+\z/)
        arg.to_i
      elsif arg.match?(/\A[+-]?\d+\.\d+\z/)
        arg.to_f
      else
        # Multi-byte / non-numeric: prefer first byte (URL-encode style) when
        # numeric formats reject the whole string.
        (arg.bytesize > 0) ? arg.getbyte(0) : 0
      end
    when Symbol
      s = arg.to_s
      s.match?(/\A[+-]?\d+\z/) ? s.to_i : arg
    else
      arg
    end
  end

  def coerce_args(args)
    args.map { |a| coerce_arg(a) }
  end

  def sprintf_retry(orig_method, fmt, args)
    coerced = coerce_args(args)
    orig_method.call(fmt, *coerced)
  end
end

module Kernel
  alias_method :__tg_sprintf_orig, :sprintf unless method_defined?(:__tg_sprintf_orig)
  alias_method :__tg_format_orig, :format unless method_defined?(:__tg_format_orig)

  def sprintf(fmt, *args)
    __tg_sprintf_orig(fmt, *args)
  rescue ArgumentError, TypeError => e
    msg = e.message.to_s
    unless msg =~ /Integer|nil into Integer|invalid value for Integer|can't convert/i
      raise
    end
    TGSprintfCompat.sprintf_retry(method(:__tg_sprintf_orig), fmt, args)
  end
  module_function :sprintf

  def format(fmt, *args)
    __tg_format_orig(fmt, *args)
  rescue ArgumentError, TypeError => e
    msg = e.message.to_s
    unless msg =~ /Integer|nil into Integer|invalid value for Integer|can't convert/i
      raise
    end
    TGSprintfCompat.sprintf_retry(method(:__tg_format_orig), fmt, args)
  end
  module_function :format
end

class String
  alias_method :__tg_percent_orig, :% unless method_defined?(:__tg_percent_orig)

  def %(arg)
    __tg_percent_orig(arg)
  rescue ArgumentError, TypeError => e
    msg = e.message.to_s
    unless msg =~ /Integer|nil into Integer|invalid value for Integer|can't convert/i
      raise
    end
    args = arg.is_a?(Array) ? arg : [arg]
    coerced = TGSprintfCompat.coerce_args(args)
    __tg_percent_orig(arg.is_a?(Array) ? coerced : coerced[0])
  end
end

STDERR.puts "[tg-early] sprintf/format/String#% Ruby 1.8-compat shim installed"
STDERR.flush

# Snapshot mkxp's built-in Input methods (Essentials replaces these with Win32API)
if defined?(Input)
  $TG_NATIVE_INPUT = {}
  %i[press? trigger? repeat? dir4 dir8].each do |m|
    if Input.respond_to?(m)
      $TG_NATIVE_INPUT[m] = Input.method(m)
    end
  end
  # Also keep raw key access if present
  if Input.respond_to?(:raw_key_states)
    $TG_NATIVE_INPUT[:raw_key_states] = Input.method(:raw_key_states)
  elsif defined?(System) && System.respond_to?(:raw_key_states)
    $TG_NATIVE_INPUT[:raw_key_states] = System.method(:raw_key_states)
  end
  STDERR.puts "[tg-early] saved native Input methods: #{$TG_NATIVE_INPUT.keys.inspect}"
  STDERR.flush
end
