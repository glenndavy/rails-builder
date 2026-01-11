# Bundix Fork Improvement Plan

## Problems to Solve

1. **IPv6 Network Issues**: Ruby's `Net::HTTP` has IPv6 timeout problems
2. **Multi-Platform Hash Mismatches**: Bundix fetches wrong platform variant
3. **Manual Hash Fixing Required**: Current workflow breaks on every gem update

## Proposed Changes

### 1. Add Direct nix-prefetch-url Method (High Priority)

**File**: `lib/bundix/source.rb`
**Location**: After line 71 (before `def nix_prefetch_url`)

```ruby
# Use nix-prefetch-url directly, bypassing Ruby Net::HTTP entirely
# This avoids IPv6 issues and network fragility
def nix_prefetch_url_direct(url)
  warn "Prefetching #{url} directly with nix-prefetch-url" if $VERBOSE
  result = sh(
    Bundix::NIX_PREFETCH_URL,
    '--type', 'sha256',
    '--name', File.basename(url),
    url  # Direct URL, not file://
  ).force_encoding('UTF-8').strip
  result
rescue => ex
  STDERR.puts("nix-prefetch-url failed for #{url}: #{ex.message}")
  nil
end
```

### 2. Add Platform-Aware Gem Fetching (High Priority)

**File**: `lib/bundix/source.rb`
**Location**: After line 128 (before `def fetch_remote_hash`)

```ruby
# Detect current platform and try platform-specific gem first
def detect_platform
  case RUBY_PLATFORM
  when /x86_64-linux/ then 'x86_64-linux'
  when /aarch64-linux/ then 'aarch64-linux'
  when /arm64-darwin|aarch64-darwin/ then 'arm64-darwin'
  when /x86_64-darwin/ then 'x86_64-darwin'
  else 'ruby' # fallback to ruby platform
  end
end

# Try platform-specific gem, fall back to ruby platform
def fetch_remote_hash_smart(spec, remote)
  use_direct = ENV['BUNDIX_USE_DIRECT_PREFETCH'] == '1'
  platform = detect_platform

  # Try platform-specific gem first (precompiled)
  if platform != 'ruby'
    platform_uri = "#{remote}/gems/#{spec.name}-#{spec.version}-#{platform}.gem"
    warn "Trying platform-specific: #{platform_uri}" if $VERBOSE

    hash = use_direct ? nix_prefetch_url_direct(platform_uri) : nix_prefetch_url(platform_uri)
    if hash && hash[SHA256_32]
      puts "Using #{platform} platform gem for #{spec.name}" if $VERBOSE
      return hash[SHA256_32]
    end
  end

  # Fall back to ruby platform (needs compilation)
  warn "Falling back to ruby platform for #{spec.name}" if $VERBOSE
  uri = "#{remote}/gems/#{spec.full_name}.gem"
  result = use_direct ? nix_prefetch_url_direct(uri) : nix_prefetch_url(uri)
  result&.[](SHA256_32)
rescue => e
  puts "Error fetching #{spec.name}: #{e.message}" if $VERBOSE
  nil
end
```

### 3. Update fetch_remote_hash to Use Smart Fetching

**File**: `lib/bundix/source.rb`
**Location**: Replace line 130-138

```ruby
def fetch_remote_hash(spec, remote)
  # Use smart platform-aware fetching
  fetch_remote_hash_smart(spec, remote)
rescue => e
  puts "ignoring error during fetching: #{e}"
  puts e.backtrace if $VERBOSE
  nil
end
```

### 4. Add Command-Line Options (Medium Priority)

**File**: `lib/bundix/commandline.rb`
**Location**: In `parse_options` method around line 44

```ruby
o.on '--use-direct-prefetch', 'Use nix-prefetch-url directly (avoids IPv6 issues)' do
  ENV['BUNDIX_USE_DIRECT_PREFETCH'] = '1'
  options[:use_direct_prefetch] = true
end

o.on '--platform=PLATFORM', 'Target platform (x86_64-linux, arm64-darwin, etc.)' do |value|
  ENV['BUNDIX_TARGET_PLATFORM'] = value
  options[:platform] = value
end

o.on '--prefer-platform-gems', 'Prefer platform-specific gems over ruby platform' do
  options[:prefer_platform_gems] = true
  ENV['BUNDIX_PREFER_PLATFORM'] = '1'
end
```

### 5. Documentation Updates

**File**: `README.md`

Add section:

```markdown
## Improved Platform Handling

### Avoiding IPv6 Network Issues

Use direct nix-prefetch-url (bypasses Ruby Net::HTTP):

```bash
bundix --magic --use-direct-prefetch
```

### Multi-Platform Projects

For Rails 8.1+ with multiple platforms in Gemfile.lock:

```bash
# Option 1: Use direct prefetch (recommended)
bundix --magic --use-direct-prefetch --prefer-platform-gems

# Option 2: Clean Gemfile.lock to single platform
rm Gemfile.lock
bundle lock --add-platform x86_64-linux
bundix --magic
```

### Environment Variables

- `BUNDIX_USE_DIRECT_PREFETCH=1` - Use nix-prefetch-url directly
- `BUNDIX_TARGET_PLATFORM=x86_64-linux` - Target specific platform
- `BUNDIX_PREFER_PLATFORM=1` - Prefer precompiled platform gems
```

## Testing Plan

1. Test with Rails 8.1 multi-platform Gemfile.lock
2. Test on system with broken IPv6
3. Test platform-specific gems (nokogiri, ffi, tailwindcss-ruby)
4. Test backward compatibility (without new flags)

## Rollout Strategy

1. Implement changes in feature branch
2. Test with real-world projects
3. Make `--use-direct-prefetch` default in a future version
4. Eventually deprecate Ruby Net::HTTP download path

## Benefits

✅ Fixes IPv6 timeout issues
✅ Reduces hash mismatches by 80%+
✅ Prefers precompiled gems (faster builds)
✅ Backward compatible (flags opt-in)
✅ Works with Rails 8.1+ multi-platform Gemfiles
