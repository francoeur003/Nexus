# Homebrew Cask formula for Nexus
# Hosted directly in the Nexus repo — no separate tap repo needed.
#
# Install:
#   brew tap francoeur003/nexus https://github.com/francoeur003/Nexus
#   brew install --cask nexus
#
# Upgrade (after a new GitHub Release is published):
#   brew upgrade --cask nexus

cask "nexus" do
  version "1.0.0"
  sha256 "3faa54269befd666a6bdf8658b10a9cddd516eb11ef0ff6fbff66eb208ba5b54"

  url "https://github.com/francoeur003/Nexus/releases/download/v#{version}/Nexus-#{version}.dmg"
  name "Nexus"
  desc "Real-time Apple Silicon system monitor for Hermes Agent workflows"
  homepage "https://github.com/francoeur003/Nexus"

  # Apple Silicon only — M1 through M5+, macOS 13 Ventura and later
  depends_on macos: ">= :ventura"
  depends_on arch:  :arm64

  app "Nexus.app"

  # Post-install: install the privileged helper that powers GPU, temps, and power rails.
  # The helper reads IOReport and SMC directly — no third-party tools required.
  postflight do
    helper_dir  = "/Users/Shared/Nexus"
    helper_path = "#{helper_dir}/nexus-helper"

    # Only install if the helper isn't already present and working
    unless File.executable?(helper_path)
      system_command "/bin/mkdir", args: ["-p", helper_dir], sudo: true
      system_command "/bin/cp",
                     args: ["#{staged_path}/Nexus.app/Contents/MacOS/nexus-helper", helper_path],
                     sudo: true
      system_command "/bin/chmod", args: ["755", helper_path], sudo: true
    end
  end

  caveats <<~EOS
    Nexus no longer requires mactop.
    If you had it installed only for this monitor, you can safely remove it:
      brew uninstall mactop

    What's new: CPU die hotspot · fan RPM · chip variant (M2 Pro, M2 Max…)
    Changelog: https://github.com/francoeur003/Nexus/blob/main/CHANGELOG.md
  EOS

  # Uninstall: quit app and remove helper
  uninstall quit:   "com.francoeur003.Nexus",
            delete: "/Users/Shared/Nexus/nexus-helper"

  zap trash: [
    "~/Library/Preferences/com.francoeur003.Nexus.plist",
    "~/Library/Application Support/Nexus",
    "~/Library/Caches/com.francoeur003.Nexus",
    "/etc/sudoers.d/nexus-helper",
  ]
end
