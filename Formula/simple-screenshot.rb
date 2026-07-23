class SimpleScreenshot < Formula
  desc "Fast, lightweight native screenshot and screen recording app for macOS"
  homepage "https://github.com/hiroshi-kamikawa/macos-simple-screenshot"
  url "https://github.com/hiroshi-kamikawa/macos-simple-screenshot/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "4dc8cf633a5e59f29b9754938fe3bb82324b4721751dcf95e416b041d8442d7e"
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
