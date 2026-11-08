# frozen_string_literal: true

require_relative "test_helper"
require "open3"

class BootScriptsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_boot_exits_127_when_ruby_prefix_is_missing
    prefix = File.join(Dir.mktmpdir("agenda-boot-"), Faker::Alphanumeric.alpha(number: 8))

    stdout, stderr, status = Open3.capture3(
      { "RUBY_PREFIX" => prefix },
      "bash", File.join(ROOT, "bin/boot"),
      chdir: ROOT
    )

    assert_equal 127, status.exitstatus, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    assert_includes stderr, prefix
  end

  def test_install_ruby_prefix_copies_src_bin_ruby_into_destination
    src = Dir.mktmpdir("agenda-ruby-src-")
    dest = File.join(Dir.mktmpdir("agenda-ruby-dest-"), Faker::Alphanumeric.alpha(number: 8))
    FileUtils.mkdir_p(File.join(src, "bin"))
    ruby_bin = File.join(src, "bin", "ruby")
    File.write(ruby_bin, "#!/bin/sh\necho copied\n")
    FileUtils.chmod(0o755, ruby_bin)

    stdout, stderr, status = Open3.capture3(
      { "RUBY_SRC" => src, "RUBY_PREFIX" => dest },
      "bash", File.join(ROOT, "bin/install-ruby-prefix")
    )

    assert status.success?, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    copied = File.join(dest, "bin", "ruby")
    assert File.executable?(copied)
    assert_equal File.read(ruby_bin), File.read(copied)
  end

  def test_install_ruby_prefix_refuses_a_system_root
    dest = File.join(Dir.mktmpdir("agenda-ruby-dest-"), Faker::Alphanumeric.alpha(number: 8))

    stdout, stderr, status = Open3.capture3(
      { "RUBY_SRC" => "/usr", "RUBY_PREFIX" => dest },
      "bash", File.join(ROOT, "bin/install-ruby-prefix")
    )

    refute status.success?, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    assert_includes stderr, "/usr"
    refute File.exist?(dest)
  end

  def test_boot_runs_puma_through_the_copied_ruby
    prefix = Dir.mktmpdir("agenda-ruby-prefix-")
    probe = File.join(Dir.mktmpdir("agenda-boot-probe-"), "argv.txt")
    FileUtils.mkdir_p(File.join(prefix, "bin"))
    File.write(File.join(prefix, "bin", "ruby"), <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" > #{probe}
      exit 0
    SH
    FileUtils.chmod(0o755, File.join(prefix, "bin", "ruby"))

    stdout, stderr, status = Open3.capture3(
      { "RUBY_PREFIX" => prefix },
      "bash", File.join(ROOT, "bin/boot"),
      chdir: ROOT
    )

    assert status.success?, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    recorded = File.read(probe)
    assert_includes recorded, "-S"
    assert_includes recorded, "bundle"
    assert_includes recorded, "puma"
    assert_includes recorded, "config/puma.rb"
  end
end
