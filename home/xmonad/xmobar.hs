 Config {
  font =
  "xft:Iosevka:pixelsize=16:antialiase=true:autohinting=true:Regular"
  , borderColor = "black"
  , border = TopB
  , bgColor = "#0d0b09"
  , fgColor = "#DC9223"
  , position = Top
  , textOffset = -1
  , iconOffset = -1
  , lowerOnStart = False
  , pickBroadest = False
  , persistent = True
  , hideOnStart = False
  , iconRoot = "."
  , allDesktops = False
  , overrideRedirect = True
  , commands =
    [ Run Memory ["-t","<usedratio>%"] 10
    , Run Swap [] 10
    , Run Date "%I:%M:%S %a %m/%d/%Y" "date" 10
    , Run Battery
      [ "--template" , "<acstatus>"
      , "--Low"      , "15"
      , "--High"     , "50"
      , "--low"      , "#B78B26"
      , "--normal"   , "#AA9b67"
      , "--high"     , "red"
      , "--"                                -- battery specific options
      , "-o"  , "<left>% (<timeleft>)"      -- discharging status
      , "-O"  , "<fc=#dAA520>Charging</fc>" -- AC "on" status
      , "-i"  , "<fc=#006000>Charged</fc>"  -- charged status
      ] 50
    , Run MultiCpu
      [ "--template" , "<total0>% <total1>% <total2>% <total3>% <total4>% <total5>% <total6>% <total7>%"
      , "--Low"      , "50"
      , "--High"     , "85"
      , "--low"      , "#B78B26"
      , "--normal"   , "#AA9b67"
      , "--high"     , "red"
      ] 10
    , Run StdinReader
    ]
    , sepChar = "%"
    , alignSep = "}{"
    , template = "%StdinReader% }{ CPU: %multicpu% | M: %memory% * %swap% | %date% | %battery%"
  }
