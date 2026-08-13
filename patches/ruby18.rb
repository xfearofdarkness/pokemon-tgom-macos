# Ruby 1.8 (RGSS) → Ruby 3/4 (mkxp-z) compatibility
#
# RPG Maker XP / older Pokémon Essentials target Ruby 1.8.7 semantics.
# mkxp-z runs modern MRI. This file is preloaded via early_compat / Kawariki
# and must stay defensive (idempotent, no game-specific requires).
#
# See docs/DEVELOPMENT.md for the audit of PE script patterns.

module Ruby18
  module ObjectPatch
    # Object#type was an alias for Object#class (removed in 1.9)
    def type
      self.class
    end
  end

  class IncludeStringArray < Array
    def include?(thing)
      if thing.is_a?(String)
        super(thing.to_sym)
      else
        super
      end
    end
  end

  module KernelPatch
    # Kernel#methods returned String names in 1.8; 1.9+ returns Symbols.
    # PE sometimes does methods.include?("foo").
    def methods(*)
      IncludeStringArray.new(super)
    end

    def singleton_methods(*)
      IncludeStringArray.new(super)
    end
  end

  module ModulePatch
    def instance_methods(*)
      IncludeStringArray.new(super)
    end

    def public_instance_methods(*)
      IncludeStringArray.new(super)
    end

    def private_instance_methods(*)
      IncludeStringArray.new(super)
    end
  end

  module ArrayPatch
    # Array#nitems — count of non-nil entries (removed)
    def nitems
      count { |i| !i.nil? }
    end

    # Array#choice — random element (removed; use sample)
    def choice
      sample
    end
  end

  module HashPatch
    # Hash#index(value) → key for value (renamed to #key in 1.9)
    def index(value)
      key(value)
    end
  end

  # Apply once
  unless Object.ancestors.include?(ObjectPatch)
    Object.prepend ObjectPatch
    Module.prepend ModulePatch
    Kernel.prepend KernelPatch
    Array.prepend ArrayPatch
    Hash.prepend HashPatch
  end
end

# ---------------------------------------------------------------------------
# Thread.critical — global "interpreter lock" flag in 1.8; removed in 1.9+
# Essentials BitmapCache::WeakRef toggles it around ObjectSpace finalizers.
# ---------------------------------------------------------------------------
unless Thread.respond_to?(:critical)
  class Thread
    @critical = false
    class << self
      attr_accessor :critical
    end
  end
end
Thread.critical = false if Thread.respond_to?(:critical=)

# ---------------------------------------------------------------------------
# Fixnum / Bignum — unified into Integer in 2.4; constants removed later
# ---------------------------------------------------------------------------
Object.const_set(:Fixnum, Integer) unless defined?(Fixnum)
Object.const_set(:Bignum, Integer) unless defined?(Bignum)

# ---------------------------------------------------------------------------
# File.exists? / Dir.exists? — removed in Ruby 3.2 (use exist?)
# Used by Compiler_PBS and some tools when recompiling PBS data.
# ---------------------------------------------------------------------------
class << File
  alias_method :exists?, :exist? unless method_defined?(:exists?)
end
class << Dir
  alias_method :exists?, :exist? unless method_defined?(:exists?)
end

# ---------------------------------------------------------------------------
# Integer#chr — RGSS builds binary/UTF-8 bytestreams with high bytes:
#   (0x80 | n).chr
# On some Ruby builds, chr without encoding raises RangeError for >127.
# Force ASCII-8BIT (binary) for single-byte values when no encoding given.
# ---------------------------------------------------------------------------
class Integer
  alias_method :__tg_chr_orig, :chr unless method_defined?(:__tg_chr_orig)

  def chr(*args)
    if args.empty? && self >= 0 && self <= 0xFF
      __tg_chr_orig(Encoding::ASCII_8BIT)
    else
      __tg_chr_orig(*args)
    end
  end
end

# ---------------------------------------------------------------------------
# String#to_a — removed; 1.8 yielded lines (similar to each_line.to_a)
# ---------------------------------------------------------------------------
class String
  def to_a
    lines.to_a
  end unless method_defined?(:to_a)
end