# Fix Essentials screen scaling under mkxp-z:
# - Keep logical game size SCREEN_WIDTH x SCREEN_HEIGHT (512x384)
# - Let mkxp scale that framebuffer to the real window (no top-left postage stamp)
# - Force resize factor 1 and call native Graphics.resize_screen

STDOUT.sync = true

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

    def pbConfigureWindowedScreen(_value)
      border = $PokemonSystem ? $PokemonSystem.border : 0
      $ResizeOffsetX = [0, BORDER_WIDTH][border] rescue 0
      $ResizeOffsetY = [0, BORDER_HEIGHT][border] rescue 0
      # Always 1x logical
      pbSetResizeFactor2(1.0, true)
    end

    def pbConfigureFullScreen
      # Map "fullscreen" option to mkxp fullscreen toggle if available
      begin
        Graphics.fullscreen = true if Graphics.respond_to?(:fullscreen=)
      rescue StandardError
      end
      $ResizeOffsetX = 0
      $ResizeOffsetY = 0
      pbSetResizeFactor2(1.0, true)
    end

    def pbSetResizeFactor(factor = 1, norecalc = false)
      # Ignore half/double/fullscreen size indices from options; keep logical 1x
      pbConfigureWindowedScreen(1.0)
    end

    # Apply immediately: framebuffer = logical game size
    pbSetResizeFactor2(1.0, true)

    # mkxp-z: resize_screen = RGSS resolution; resize_window = OS window
    # Keep 512x384 drawing surface; enlarge window so backend scales & centers it
    begin
      if Graphics.respond_to?(:oldresizescreen)
        Graphics.oldresizescreen(SCREEN_WIDTH, SCREEN_HEIGHT)
      end
      if Graphics.respond_to?(:resize_window)
        # 2.5x → 1280x960 fills cleanly for 4:3; user can still resize
        Graphics.resize_window(1024, 768)
      end
    rescue => e
      Preload.print "display_fix window: #{e}"
    end

    Preload.print "display_fix: screen #{SCREEN_WIDTH}x#{SCREEN_HEIGHT}, window scaled by mkxp"
  rescue => e
    Preload.print "display_fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "display_fix: on_boot hook registered"
