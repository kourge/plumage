Plumage
=======

Convert between different color schema formats on Mac OS X, such as
Terminal.app and iTerm2. At least MacRuby 0.9 is required, but if you have Mac
OS X Lion installed, you're good to go. There is no need to locate where your
MacRuby installation is; on launch, Plumage searches for an installation and
relaunches itself in MacRuby.

Examples
--------
Convert a Terminal.app exported profile to an iTerm2 color preset:
```bash
$ ./plumage.rb -i terminalapp -o iterm2 ~/Desktop/Basic.terminal ~/Desktop/Basic.itermcolors
```

Automatically detect input format and convert to a Terminal.app profile that
can be imported:
```bash
$ ./plumage -o terminalapp ~/Desktop/mystery_colors ~/Desktop/Colors.terminal
```

Automatically detect input format and convert to an iTerm2 color preset and
dump to standard output:
```bash
$ ./plumage -o iterm2 ~/Desktop/mystery_colors
```

