class SimpleScreenshot < Formula
  desc "Fast, lightweight native screenshot and screen recording app for macOS"
  homepage "https://github.com/hiroshi-kamikawa/macos-simple-screenshot"
  url "https://github.com/hiroshi-kamikawa/macos-simple-screenshot/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "ccbec4fd383d47f7c0397111f411b83f00c16df60f081eea8fd00cb4d25be215"
  license "MIT"
  depends_on xcode: ["15.0", :build]

  def install
    ENV["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"
    system "sh", "scripts/build-app.sh"
    prefix.install "dist/Simple Screenshot.app"
    bin.write_exec_script prefix/"Simple Screenshot.app/Contents/MacOS/SimpleScreenshot"
  end

  def caveats
    <<~EOS
      Open System Settings > Privacy & Security > Screen & System Audio Recording
      and allow Simple Screenshot on first launch.
    EOS
  end

  test do
    assert_predicate prefix/"Simple Screenshot.app/Contents/MacOS/SimpleScreenshot", :executable?
  end
end
