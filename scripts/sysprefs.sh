#!/usr/bin/env bash

if [[ "$(uname -o)" != "Darwin" ]]; then
  echo "This script is intended for macOS only." >&2
  exit 1
fi

# h/t https://github.com/mathiasbynens/dotfiles/blob/main/.macos

# close any open system preferences panes, to prevent them from overriding settings we're about to change
osascript -e 'tell application "System Preferences" to quit'
osascript -e 'tell application "System Settings" to quit'

# ask for the administrator password upfront and update existing `sudo` time stamp until `.macos` has finished
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

echo "Updating computer name..."
if [ -n "${CUSTOM_HOSTNAME}" ]; then
  sudo scutil --set ComputerName "${CUSTOM_HOSTNAME}"
  sudo scutil --set HostName "${CUSTOM_HOSTNAME}"
  sudo scutil --set LocalHostName "${CUSTOM_HOSTNAME}"
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "${CUSTOM_HOSTNAME}"
fi

echo "Updating system configurations..."

# disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

# set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# always show scrollbars; possible values: `WhenScrolling`, `Automatic` and `Always`
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# disable the over-the-top focus ring animation
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false

# adjust toolbar title rollover delay
defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0

# increase window resize speed for cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# expand save and panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# disable the "are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# display ascii control characters using caret notation in standard text views
defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

# disable resume system-wide
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# set help viewer windows to non-floating mode
defaults write com.apple.helpviewer DevMode -bool true

# disable automatic capitalization as it's annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# disable smart dashes as they're annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# disable automatic period substitution as it's annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# disable smart quotes as they're annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# increase sound quality for bluetooth headphones/headsets
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# use scroll gesture with the ctrl (^) modifier key to zoom and follow the keyboard focus while zoomed in
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

# disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Set language and text formats
# Note: if you're in the US, replace `EUR` with `USD`, `Centimeters` with
# `Inches`, `en_GB` with `en_US`, and `true` with `false`.
defaults write NSGlobalDomain AppleLanguages -array "en"
defaults write NSGlobalDomain AppleLocale -string "en_ID"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# enable lid wakeup
sudo pmset -a lidwake 1

# restart automatically on power loss
sudo pmset -a autorestart 1

# restart automatically if the computer freezes
sudo systemsetup -setrestartfreeze on

# disable machine sleep while charging
sudo pmset -c sleep 0

# save screenshots to the desktop
mkdir -p "${HOME}/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# save screenshots in png format (other options: bmp, gif, jpg, pdf, tiff)
defaults write com.apple.screencapture type -string "png"

# enable subpixel font rendering on non-apple lcds (https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501)
defaults write NSGlobalDomain AppleFontSmoothing -int 1

# enable hidpi display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

# show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# finder: show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# when performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# remove the spring loading delay for directories
defaults write NSGlobalDomain com.apple.springing.delay -float 0

# avoid creating .DS_Store files on network or usb volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# disable disk image verification
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true

# show item info near icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

# show item info to the right of the icons on the desktop
/usr/libexec/PlistBuddy -c "Set DesktopViewSettings:IconViewSettings:labelOnBottom false" ~/Library/Preferences/com.apple.finder.plist

# enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# use list view in all finder windows by default
# four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# enable airdrop over ethernet and on unsupported macs running lion
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# show the ~/library folder
chflags nohidden ~/Library && xattr -d com.apple.FinderInfo ~/Library

# show the /volumes folder
sudo chflags nohidden /Volumes

# expand the following file info panes:
# "general", "open with", and "sharing & permissions"
defaults write com.apple.finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true

# enable highlight hover effect for the grid view of a stack (dock)
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# enable spring loading for all dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# show indicator lights for open applications in the dock
defaults write com.apple.dock show-process-indicators -bool true

# speed up mission control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# don't automatically rearrange spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# automatically hide and show the dock
defaults write com.apple.dock autohide -bool true

# make dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# don't show recent applications in dock
defaults write com.apple.dock show-recents -bool false

# reset launchpad, but keep the desktop wallpaper intact
find "${HOME}/Library/Application Support/Dock" -name "*-*.db" -maxdepth 1 -delete

# privacy: don't send search queries to apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# press tab to highlight each item on a web page
defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

# show the full url in the address bar (note: this still hides the scheme)
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# set safari's home page to `about:blank` for faster loading
defaults write com.apple.Safari HomePage -string "about:blank"

# prevent safari from opening 'safe' files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# hide safari's bookmarks bar by default
defaults write com.apple.Safari ShowFavoritesBar -bool false

# hide safari's sidebar in top sites
defaults write com.apple.Safari ShowSidebarInTopSites -bool false

# disable safari's thumbnail cache for history and top sites
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

# enable safari's debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# make safari's search banners default to contains instead of starts with
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

# remove useless icons from safari's bookmarks bar
defaults write com.apple.Safari ProxiesInBookmarksBar "()"

# enable the develop menu and the web inspector in safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# add a context menu item for showing the web inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# enable continuous spellchecking
defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true

# disable auto-correct
defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false

# disable autofill
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false
defaults write com.apple.Safari AutoFillCreditCardData -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false

# warn about fraudulent websites
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

# block pop-up windows
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

# disable auto-playing video
defaults write com.apple.Safari WebKitMediaPlaybackAllowsInline -bool false
defaults write com.apple.SafariTechnologyPreview WebKitMediaPlaybackAllowsInline -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false
defaults write com.apple.SafariTechnologyPreview com.apple.Safari.ContentPageGroupIdentifier.WebKit2AllowsInlineMediaPlayback -bool false

# enable "do not track"
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

# copy email addresses as `foo@example.com` instead of `foo bar <foo@example.com>` in mail.app
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# add the keyboard shortcut ⌘ + enter to send an email in mail.app
defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" "@\U21a9"

# display emails in threaded mode, sorted by date (oldest at the top)
defaults write com.apple.mail DraftsViewerAttributes -dict-add "DisplayInThreadedMode" -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortedDescending" -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortOrder" -string "received-date"

# disable inline attachments (just show the icons)
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# disable automatic spell checking
defaults write com.apple.mail SpellCheckingBehavior -string "NoSpellCheckingEnabled"

# hide spotlight tray-icon (and subsequent helper)
sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search

# disable spotlight indexing for any volume that gets mounted and has not yet been indexed before.
# use `sudo mdutil -i off "/volumes/foo"` to stop indexing any volume.
sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

# only use utf-8 in terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# enable secure keyboard entry in terminal.app (https://security.stackexchange.com/a/47786/8918)
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# disable the annoying line marks
defaults write com.apple.Terminal ShowLineMarks -int 0

# prevent time machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# disable local time machine backups
hash tmutil &>/dev/null && sudo tmutil disablelocal

# show the main window when launching activity monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# show all processes in activity monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# enable the debug menu in address book
defaults write com.apple.addressbook ABShowDebugMenu -bool true

# enable dashboard dev mode (allows keeping widgets on the desktop)
defaults write com.apple.dashboard devmode -bool true

# enable the debug menu in ical (pre-10.8)
defaults write com.apple.iCal IncludeDebugMenu -bool true

# use plain text mode for new textedit documents
defaults write com.apple.TextEdit RichText -int 0
# open and save files as utf-8 in textedit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# enable the debug menu in disk utility
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true

# enable the webkit developer tools in the mac app store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# enable debug menu in the mac app store
defaults write com.apple.appstore ShowDebugMenu -bool true

# enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# install system data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# prevent the app store to reboot machine on macos updates
defaults write com.apple.commerce AutoUpdateRestartRequired -bool false

# prevent photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# disable smart quotes as it's annoying for messages that contain code
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

# disable continuous spell checking
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false

echo "Done! ✨"
