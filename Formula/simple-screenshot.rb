class SimpleScreenshot < Formula
  desc "Fast, lightweight native screenshot and screen recording app for macOS"
  homepage "https://github.com/hiroshi-kamikawa/macos-simple-screenshot"
  url "https://github.com/hiroshi-kamikawa/macos-simple-screenshot/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "d23b97e9c225d71f55a66fb099c617430b6a42799f922ca3e1d1626a0668ee6b"
  license "MIT"
  depends_on xcode: ["15.0", :build]

  def install
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
