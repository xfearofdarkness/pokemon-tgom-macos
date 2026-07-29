# Kawariki user script: native mkxp Input + explicit Enter/Space/Z for confirm.
STDOUT.sync = true
STDERR.sync = true

$TG_NATIVE_INPUT = {}
if defined?(Input)
  %i[press? trigger? repeat? dir4 dir8 update pressex? triggerex?].each do |m|
    $TG_NATIVE_INPUT[m] = Input.method(m) if Input.respond_to?(m)
  end
  if Input.respond_to?(:raw_key_states)
    $TG_NATIVE_INPUT[:raw_key_states] = Input.method(:raw_key_states)
  elsif defined?(System) && System.respond_to?(:raw_key_states)
    $TG_NATIVE_INPUT[:raw_key_states] = System.method(:raw_key_states)
  end
end
Preload.print "tg-input-fix: native methods = #{$TG_NATIVE_INPUT.keys.inspect}"

# SDL scancodes (mkxp raw_key_states index)
module TgKeys
  RETURN = 40
  ESCAPE = 41
  SPACE  = 44
  X      = 27
  Z      = 29
  C      = 6
  UP     = 82
  DOWN   = 81
  LEFT   = 80
  RIGHT  = 79

  CONFIRM = [RETURN, SPACE, Z, C].freeze
  CANCEL  = [ESCAPE, X].freeze
end

def tg_raw_states
  if $TG_NATIVE_INPUT[:raw_key_states]
    $TG_NATIVE_INPUT[:raw_key_states].call
  elsif defined?(Input) && Input.respond_to?(:raw_key_states)
    Input.raw_key_states
  elsif defined?(System) && System.respond_to?(:raw_key_states)
    System.raw_key_states
  else
    nil
  end
end

def tg_down?(states, code)
  return false unless states
  v = states[code]
  # Array of bool (mkxp-z 2.4 Input.raw_key_states) or bytes (System)
  v == true || (v.is_a?(Integer) && v != 0)
end

def tg_any_down?(states, codes)
  codes.any? { |c| tg_down?(states, c) }
end

Preload.on_boot do |_ctx|
  begin
    def pbSameThread(_wnd)
      true
    end

    natives = $TG_NATIVE_INPUT || {}
    unless natives[:press?] && natives[:trigger?]
      Preload.print "tg-input-fix ERROR: native Input missing"
      next
    end

    # Edge state for our extra scancode mappings
    $tg_prev_confirm = false
    $tg_prev_cancel  = false
    $tg_prev_dirs    = { up: false, down: false, left: false, right: false }

    Input.singleton_class.class_eval do
      define_method(:update) do
        natives[:update].call if natives[:update]

        states = tg_raw_states
        conf = tg_any_down?(states, TgKeys::CONFIRM)
        canc = tg_any_down?(states, TgKeys::CANCEL)
        $tg_confirm_trigger = conf && !$tg_prev_confirm
        $tg_cancel_trigger  = canc && !$tg_prev_cancel
        $tg_confirm_press   = conf
        $tg_cancel_press    = canc
        $tg_prev_confirm = conf
        $tg_prev_cancel  = canc

        # Don't call essentials update — it reintroduces broken Win32 polling
        # and can clear/clobber our state. F7/F8 debug are non-essential on macOS.
      end

      define_method(:press?) do |button|
        # Prefer scancode hybrid for confirm/cancel (Enter etc.)
        if button == Input::C || button == 13
          return true if $tg_confirm_press
        elsif button == Input::B || button == 12
          return true if $tg_cancel_press
        end
        natives[:press?].call(button)
      end

      define_method(:trigger?) do |button|
        if button == Input::C || button == 13
          return true if $tg_confirm_trigger
        elsif button == Input::B || button == 12
          return true if $tg_cancel_trigger
        end
        natives[:trigger?].call(button)
      end

      define_method(:repeat?) do |button|
        natives[:repeat?] ? natives[:repeat?].call(button) : press?(button)
      end

      if natives[:dir4]
        define_method(:dir4) { natives[:dir4].call }
      end
      if natives[:dir8]
        define_method(:dir8) { natives[:dir8].call }
      end
    end

    # Ensure first frame runs our update soon
    Preload.print "tg-input-fix: NATIVE+scancode Input (Enter/Space/Z=confirm, Esc/X=cancel)"
  rescue => e
    Preload.print "tg-input-fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "tg-input-fix: on_boot hook registered"
