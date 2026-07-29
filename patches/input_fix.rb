# Also loaded via preloadScript after kawariki (backup if *.kawariki.rb cwd misses)
# Primary fix lives in game/…/input_fix.kawariki.rb

STDOUT.sync = true
if defined?(Preload) && Preload.respond_to?(:on_boot)
  # kawariki file already registers the real hook; this is a no-op safety log
  STDERR.puts "[tg-input-fix] preloadScript companion loaded"
else
  STDERR.puts "[tg-input-fix] Preload not defined yet"
end
