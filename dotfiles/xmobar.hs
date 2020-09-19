Config
        { font = "xft:PragmataPro Mono:style=Regular:size=14"
        , bgColor = "yellow"
        , fgColor = "red"
        , position = Top
        , border = TopB
        , alpha = 210
        , commands =
            [ Run StdinReader
            , Run Cpu
              [ "-t", "<total>%"
              , "-L", "10"
              , "-H", "50"
              , "-l", "#00ff00"
              , "-h", "ff0000" ] 10
            , Run Date "%a %d.%m %T" "date" 10
            , Run Memory [] 10
            , Run DynNetwork
                [ "-t", "<tx>,<rx> KB/s | "
                , "-L", "10000"
                , "-H", "500000"
                , "-l", "#ff"
                , "-n", "#00ef00"
                , "-h", "#00ff00" ] 10
          ]
        , sepChar = "%"
        , alignSep = "}{"

        -- layout
        , template = "%StdinReader% }{ %memory% | %dynnetwork%%cpu% <fc=#0000dd>%date%</fc> "
        }

