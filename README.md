# Install brew

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

# Install Sketchybar (Macos only)

[guide](https://www.josean.com/posts/sketchybar-setup)

```
brew tap FelixKratz/formulae
```

```
brew install \
    sketchybar \
    font-hack-nerd-font \
    font-sf-pro
```

```
brew install --cask sf-symbols
brew install --cask font-sketchybar-app-font
```

Hide the macos menu bar by going to Preference &rarr; Control center &rarr; Automatically hide and show menu bar &rarr; Always

Start sketchybar as a service to start when the computer starts

```
brew services start sketchybar
```

## DNS Setup

Configure to use AdGuard DNS server instead of Internet providers.
Under details &rarr; dns for your network (wifi, ethernet) change the servers to the following:

```
94.140.14.14
94.140.15.15
```

Test if your using AdGuard DNS server through [this](https://adguard.com/en/test.html) website.

Run the following command to make sure which dns server you are using:

```
scutil --dns
```
