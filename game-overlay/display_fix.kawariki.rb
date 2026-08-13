# Fix Essentials screen scaling under mkxp-z:
# - Keep logical game size SCREEN_WIDTH x SCREEN_HEIGHT (512x384)
# - Let mkxp scale that framebuffer to the real window (no top-left postage stamp)
# - Force resize factor 1 and call native Graphics.resize_screen
# - Size the OS window to the largest integer scale that fits this Mac

STDOUT.sync = true

# Logical points (Retina-aware). Leave room for menu bar, title bar, Dock.
# margin: :windowed (chrome) or :full (exclusive fullscreen, almost no inset).
def tg_usable_desktop(sw, sh, margin = :windowed)
  if margin == :full
    inset_x, inset_y = 0, 0
  else
    inset_x, inset_y = 64, 120
  end
  uw = sw.to_i - inset_x
  uh = sh.to_i - inset_y
  uw = 512 if uw < 512
  uh = 384 if uh < 384
  [uw, uh]
end

# Largest n>=1 such that (gw*n) x (gh*n) fits in usable desktop.
def tg_integer_window_size(sw, sh, gw = 512, gh = 384, margin = :windowed)
  uw, uh = tg_usable_desktop(sw, sh, margin)
  n = [(uw / gw).to_i, (uh / gh).to_i].min
  n = 1 if n < 1
  n = 6 if n > 6
  [gw * n, gh * n, n]
end

def tg_mac_desktop_size
  out = `osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null`
  return nil if out.nil? || out.strip.empty?
  parts = out.strip.split(/\s*,\s*/).map { |x| x.to_i }
  return nil unless parts.length >= 4
  w = parts[2] - parts[0]
  h = parts[3] - parts[1]
  return nil if w < 320 || h < 240
  [w, h]
rescue StandardError
  nil
end

Preload.on_boot do |_ctx|
  begin
    # Prefer windowed 1x logical; mkxp upscales to the OS window
    if defined?($PokemonSystem) && $PokemonSystem
      $PokemonSystem.screensize = 1
    end

    $ResizeOffsetX   = 0
    $ResizeOffsetY   = 0
    $ResizeFactor    = 1.0
    $ResizeFactorMul = 100
    $ResizeFactorSet = true

    # Patch resize helpers so they never fight mkxp's window scaler via Win32
    def pbSetResizeFactor2(factor, force = false)
      factor = 1.0 if !factor || factor <= 0 || factor > 4
      # Under mkxp, always stay at logical 1x and let the backend scale
      factor = 1.0
      if $ResizeFactor != factor || force
        $ResizeFactor    = factor
        $ResizeFactorMul = (factor * 100).to_i
        pbRefreshResizeFactor if $ResizeFactorSet && defined?(pbRefreshResizeFactor)
      end
      $ResizeFactorSet = true
      $ResizeBorder.refresh if $HaveResizeBorder && $ResizeBorder
      w = (SCREEN_WIDTH  + $ResizeOffsetX * 2) * $ResizeFactor
      h = (SCREEN_HEIGHT + $ResizeOffsetY * 2) * $ResizeFactor
      begin
        if Graphics.respond_to?(:oldresizescreen)
          Graphics.oldresizescreen(w, h)
        elsif Graphics.respond_to?(:resize_screen)
          # Avoid recursion into Essentials wrapper if possible
          Graphics.method(:resize_screen).super_method&.call(w, h) rescue Graphics.resize_screen(w, h)
        end
      rescue => e
        Preload.print "display_fix resize_screen: #{e}"
      end
      # Do NOT call Win32API.SetWindowPos / restoreScreen — mkxp owns the window
    end

    # Never turn integer_scaling on. Windowed we pick an exact N× window
    # (already sharp). macOS green-button zoom/fullscreen only resizes the
    # window and never calls Graphics.fullscreen= — if integer lock is on,
    # that becomes a postage stamp. Off + fixedAspectRatio fills 4:3.
    def tg_set_fill_mode(smooth)
      begin
        Graphics.integer_scaling = false if Graphics.respond_to?(:integer_scaling=)
      rescue StandardError
      end
      begin
        Graphics.last_mile_scaling = false if Graphics.respond_to?(:last_mile_scaling=)
      rescue StandardError
      end
      begin
        Graphics.smooth_scaling = !!smooth if Graphics.respond_to?(:smooth_scaling=)
      rescue StandardError
      end
    end

    def tg_resize_os_window(ww, wh)
      return unless Graphics.respond_to?(:resize_window)
      begin
        Graphics.resize_window(ww, wh, true)
      rescue ArgumentError
        Graphics.resize_window(ww, wh)
      end
      Graphics.center if Graphics.respond_to?(:center)
    end

    def tg_apply_windowed_window(preferred_scale = nil)
      tg_set_fill_mode(false)
      return unless Graphics.respond_to?(:resize_window)
      gw = defined?(SCREEN_WIDTH) ? SCREEN_WIDTH : 512
      gh = defined?(SCREEN_HEIGHT) ? SCREEN_HEIGHT : 384
      desk = tg_mac_desktop_size
      if desk
        max_w, max_h, max_n = tg_integer_window_size(desk[0], desk[1], gw, gh, :windowed)
        n = preferred_scale ? [preferred_scale.to_i, max_n].min : max_n
        n = 1 if n < 1
        ww, wh = gw * n, gh * n
      else
        n = preferred_scale ? [preferred_scale.to_i, 2].min : 2
        n = 1 if n < 1
        ww, wh = gw * n, gh * n
      end
      tg_resize_os_window(ww, wh)
      Preload.print "display_fix: windowed #{ww}x#{wh} (#{n}x)"
      n
    end

    def tg_apply_fullscreen
      # Do NOT keep integer lock: on 16:9 that is a 2× postage stamp.
      # fixedAspectRatio stays on, so 512x384 grows uniformly until one
      # side of the monitor is filled (side bars only, 4:3 preserved).
      tg_set_fill_mode(true)
      $ResizeOffsetX = 0
      $ResizeOffsetY = 0
      pbSetResizeFactor2(1.0, true)
      begin
        Graphics.fullscreen = true if Graphics.respond_to?(:fullscreen=)
      rescue StandardError
      end
      Preload.print "display_fix: fullscreen (4:3 fit, no integer lock)"
    end

    def pbConfigureWindowedScreen(_value)
      border = $PokemonSystem ? $PokemonSystem.border : 0
      $ResizeOffsetX = [0, BORDER_WIDTH][border] rescue 0
      $ResizeOffsetY = [0, BORDER_HEIGHT][border] rescue 0
      pbSetResizeFactor2(1.0, true)
      begin
        Graphics.fullscreen = false if Graphics.respond_to?(:fullscreen=) && Graphics.respond_to?(:fullscreen) && Graphics.fullscreen
      rescue StandardError
      end
      tg_apply_windowed_window
    end

    def pbConfigureFullScreen
      tg_apply_fullscreen
    end

    # Options "Screen Size": 0=S 1=M 2=L 3=Full
    def pbSetResizeFactor(factor = 1, norecalc = false)
      pbSetResizeFactor2(1.0, true)
      idx = factor.to_i
      if idx >= 3
        tg_apply_fullscreen
      else
        begin
          Graphics.fullscreen = false if Graphics.respond_to?(:fullscreen=) && Graphics.respond_to?(:fullscreen) && Graphics.fullscreen
        rescue StandardError
        end
        tg_apply_windowed_window(idx + 1)
      end
    end

    # Apply immediately: framebuffer = logical game size
    pbSetResizeFactor2(1.0, true)

    begin
      if Graphics.respond_to?(:oldresizescreen)
        Graphics.oldresizescreen(SCREEN_WIDTH, SCREEN_HEIGHT)
      end
      tg_apply_windowed_window
    rescue => e
      Preload.print "display_fix window: #{e}"
    end

    # Alt+Enter uses fullscreen=. The green traffic-light button does not —
    # it only resizes the window. Watch Graphics.fullscreen and keep fill
    # mode in sync so macOS decorations get the same 4:3 fit.
    $tg_fs_seen = (Graphics.fullscreen rescue false)
    if defined?(Graphics)
      Graphics.singleton_class.class_eval do
        if method_defined?(:fullscreen=)
          alias_method :__tg_set_fullscreen, :fullscreen= unless method_defined?(:__tg_set_fullscreen)
          def fullscreen=(v)
            tg_set_fill_mode(v) if respond_to?(:tg_set_fill_mode, true)
            __tg_set_fullscreen(v)
            $tg_fs_seen = !!v
            tg_apply_windowed_window if !v && respond_to?(:tg_apply_windowed_window, true)
          end
        end
        alias_method :__tg_gfx_update, :update unless method_defined?(:__tg_gfx_update)
        def update
          __tg_gfx_update
          fs = (fullscreen rescue nil)
          return if fs.nil? || fs == $tg_fs_seen
          $tg_fs_seen = fs
          if fs
            tg_set_fill_mode(true) if respond_to?(:tg_set_fill_mode, true)
          else
            tg_set_fill_mode(false) if respond_to?(:tg_set_fill_mode, true)
            tg_apply_windowed_window if respond_to?(:tg_apply_windowed_window, true)
          end
        end
      end
    end

    Preload.print "display_fix: screen #{SCREEN_WIDTH}x#{SCREEN_HEIGHT}, window scaled by mkxp"
  rescue => e
    Preload.print "display_fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "display_fix: on_boot hook registered"
