# frozen_string_literal: true

require_relative "test_helper"
require "open3"

class BootScriptsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def write_fake_ruby_prefix(prefix, marker)
    FileUtils.mkdir_p(File.join(prefix, "bin"))
    ruby_bin = File.join(prefix, "bin", "ruby")
    File.write(ruby_bin, "#!/bin/sh\necho #{marker}\n")
    FileUtils.chmod(0o755, ruby_bin)
    ruby_bin
  end

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

  def test_install_ruby_prefix_prefers_ruby_version_file_over_newer_mise
    mise_root = Dir.mktmpdir("agenda-mise-ruby-")
    wanted = write_fake_ruby_prefix(File.join(mise_root, "3.3.6"), "ruby-3.3.6")
    write_fake_ruby_prefix(File.join(mise_root, "3.4.4"), "ruby-3.4.4")
    workdir = Dir.mktmpdir("agenda-release-")
    File.write(File.join(workdir, ".ruby-version"), "3.3.6\n")
    dest = File.join(Dir.mktmpdir("agenda-ruby-dest-"), Faker::Alphanumeric.alpha(number: 8))

    stdout, stderr, status = Open3.capture3(
      {
        "RUBY_PREFIX" => dest,
        "MISE_RUBY_ROOT" => mise_root,
        "PATH" => "/usr/bin:/bin",
        "GEM_HOME" => "",
        "GEM_PATH" => "",
        "RUBYOPT" => "",
        "BUNDLE_GEMFILE" => ""
      },
      "bash", File.join(ROOT, "bin/install-ruby-prefix"),
      chdir: workdir
    )

    assert status.success?, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    assert_equal File.read(wanted), File.read(File.join(dest, "bin", "ruby"))
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

  def test_install_ruby_prefix_copies_through_a_symlink_src
    real = Dir.mktmpdir("agenda-ruby-real-")
    FileUtils.mkdir_p(File.join(real, "bin"))
    ruby_bin = File.join(real, "bin", "ruby")
    File.write(ruby_bin, "#!/bin/sh\necho copied\n")
    FileUtils.chmod(0o755, ruby_bin)

    src_link = File.join(Dir.mktmpdir("agenda-ruby-link-"), "3.3.6")
    File.symlink(real, src_link)
    dest = File.join(Dir.mktmpdir("agenda-ruby-dest-"), Faker::Alphanumeric.alpha(number: 8))

    stdout, stderr, status = Open3.capture3(
      { "RUBY_SRC" => src_link, "RUBY_PREFIX" => dest },
      "bash", File.join(ROOT, "bin/install-ruby-prefix")
    )

    assert status.success?, "stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
    refute File.symlink?(dest)
    copied = File.join(dest, "bin", "ruby")
    assert File.file?(copied)
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
