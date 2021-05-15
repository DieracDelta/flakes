{-# OPTIONS_GHC -Wall -Werror -fno-warn-missing-signatures #-}

--import           System.Exit                    ( exitSuccess )
import           XMonad
import           XMonad.Hooks.EwmhDesktops      ( ewmh
                                                , fullscreenEventHook
                                                )
import           XMonad.Actions.CopyWindow
import           XMonad.Actions.CycleWS         ( prevWS
                                                , nextWS
                                                )
import           XMonad.Hooks.ManageDocks       ( avoidStruts
                                                , docks
                                                , manageDocks
                                                )
import           XMonad.Actions.CycleRecentWS   ( cycleRecentWS )
import           XMonad.Hooks.DynamicLog        ( statusBar
                                                , ppCurrent
                                                , ppHidden
                                                , ppTitle
                                                , xmobarPP
                                                , xmobarColor
                                                , wrap
                                                )
import           XMonad.Hooks.ManageHelpers     ( composeOne
                                                , transience
                                                , (-?>)
                                                )
import           XMonad.Hooks.SetWMName         ( setWMName )
import           XMonad.Layout.NoBorders        ( smartBorders )
import           XMonad.Layout.Renamed          ( Rename(..)
                                                , renamed
                                                )
import           XMonad.Layout.Spacing          ( Border(..)
                                                , spacingRaw
                                                )
import qualified XMonad.StackSet               as W
import qualified Data.Map                      as M
import           XMonad.Util.SpawnOnce          ( spawnOnce )

main :: IO ()
main =
  xmonad
    .   ewmh
    .   docks
    =<< statusBar "xmobar" myXmobarPP (\x -> (XMonad.modMask x, xK_u)) myConfig

-- color scheme:
-- #0d0b09 -- VERY DARK D0791A -- orange-ish B78B26 -- yellow DC9223 -- lighter yellow F49823 -- darker (ish) yellow
-- F6AD2C -- DCC53A -- f4de94 -- aa9b67 -- D0791A -- B78B26 -- DC9223 -- F49823 -- F6AD2C -- DCC53A -- f4de94
myXmobarPP = xmobarPP { ppCurrent = xmobarColor "#D0791A" "" . wrap "[" "]"  -- currently focused workspace
                      , ppHidden  = xmobarColor "#aa9b67" "" -- currently nonempty but unfocusued workspace
                      , ppTitle   = xmobarColor "#F49823" ""   -- title of currently focused program
                      }

myTerminal :: String
myTerminal = "alacritty"



myConfig = def { terminal           = myTerminal
               , focusedBorderColor = "#FF0000"
               , normalBorderColor  = "#DCC53A"
               , modMask            = mod1Mask
               , borderWidth        = 2
               , handleEventHook = fullscreenEventHook <+> handleEventHook def
               , layoutHook         = myLayoutHook
               , manageHook         = myManageHook
               , startupHook        = myStartupHook
               , workspaces         = myWorkspaces
               , keys               = myKeys
               }

ws1, ws2, ws3, ws4, ws5, ws6, ws7, ws8, ws9, ws0 :: String
ws1 = "I"
ws2 = "II"
ws3 = "III"
ws4 = "IV"
ws5 = "V"
ws6 = "VI"
ws7 = "VII"
ws8 = "VIII"
ws9 = "IX"
ws0 = "X"

myWorkspaces :: [String]
myWorkspaces = [ws1, ws2, ws3, ws4, ws5, ws6, ws7, ws8, ws9, ws0]

myStartupHook :: X ()
myStartupHook = do
  setWMName "LG3D"
  spawnOnce "feh --bg-fill ~/.wallpaper.jpg"
  spawn "Discord"
  spawn "pavucontrol"
  spawn "chromium"

myLayoutHook = smartBorders . avoidStruts $ myMainLayout

myMainLayout =
  renamed [Replace "Tall"] tiled
    ||| renamed [Replace "Wide"] (Mirror tiled)
    ||| Full
 where
  tiled =
    spacingRaw True
               (Border outer outer outer outer)
               True
               (Border inner inner inner inner)
               True
      $ Tall 1 (3 / 100) (1 / 2)
  outer = 3
  inner = 5

myManageHook :: ManageHook
myManageHook = composeAll [spawnHook, manageDocks, manageHook def]
 where
  spawnHook = composeOne
    [ transience
    , className =? "Slack" -?> doShift ws0
    , className =? "Firefox" -?> doShift ws9
    -- TODO figure out why this does not work
    , className =? "Discord" -?> doShift ws1
    , className =? "Pavucontrol" -?> doShift ws2
    ]


myKeys conf@XConfig { XMonad.modMask = modm } =
  M.fromList
    $  [ ((modm, xK_Return)              , spawn $ XMonad.terminal conf)
       , ((modm, xK_t)                   , spawn "emacsclient -c")
       , ((modm, xK_d), spawn "rofi -show combi -combi-modi window,drun")
       , ((modm .|. shiftMask, xK_d), spawn "rofi -show run -sidebar-mode")
       , ((modm .|. shiftMask, xK_x)     , kill1)
       , ((modm, xK_x)                   , kill)
       , ((modm, xK_space)               , sendMessage NextLayout)
       , ((modm .|. shiftMask, xK_space) , setLayout $ XMonad.layoutHook conf)
       , ((modm, xK_n)                   , refresh)
       , ((modm, xK_j)                   , windows W.focusDown)
       , ((modm, xK_k)                   , windows W.focusUp)
       , ((modm .|. shiftMask, xK_j)     , windows W.swapDown)
       , ((modm .|. shiftMask, xK_k)     , windows W.swapUp)
       , ((modm, xK_m)                   , windows W.focusMaster)
       , ((modm .|. shiftMask, xK_Return), windows W.swapMaster)
       , ((modm, xK_h)                   , sendMessage Shrink)
       , ((modm, xK_l)                   , sendMessage Expand)
       , ((modm .|. shiftMask, xK_t)     , withFocused $ windows . W.sink)
       , ((modm .|. shiftMask, xK_v)     , sendMessage (IncMasterN 1))
       , ((modm .|. shiftMask, xK_b)     , sendMessage (IncMasterN (-1)))
       --, ( (modm .|. shiftMask, xK_c)
         --, io exitSuccess
         --)
       -- , ((modm, xK_q), spawn "xmonad --recompile && xmonad --restart")
       --
       , ((modm, xK_b)                    , spawn "bluetoothctl connect 60:AB:D2:3A:F4:06")
       , ((modm .|. shiftMask, xK_b)      , spawn "bluetoothctl connect 70:CE:8C:1B:4C:D5")
       , ((modm .|. shiftMask, xK_Up)     , spawn "playerctl play")
       , ((modm .|. shiftMask, xK_Down)   , spawn "playerctl pause")
       , ((modm .|. shiftMask, xK_Right)  , spawn "playerctl next")
       , ((modm .|. shiftMask, xK_Left)   , spawn "playerctl previous")
       , ((modm .|. controlMask, xK_Right), spawn "amixer sset Master 5%+")
       , ((modm .|. controlMask, xK_Left) , spawn "amixer sset Master 5%-")
       , ((modm .|. controlMask, xK_Down) , spawn "amixer sset Master mute")
       , ((modm .|. controlMask, xK_Up)   , spawn "amixer sset Master unmute")
       , ( (modm, xK_p)
         , spawn "maim -s | xclip -selection clipboard -t image/png"
         )
       , ((modm .|. shiftMask, xK_p), spawn "deepfry")
       , ((modm , xK_o), spawn "flameshot gui")
       , ((modm, xK_comma)          , prevWS)
       , ((modm, xK_period)         , nextWS)
       , ((modm, xK_Tab)            , cycleRecentWS [xK_Tab] xK_Tab xK_Tab)
       ]
    ++ [ ((m .|. modm, k), windows $ f i)
       | (f, m, _n) <-
         [ (W.greedyView, 0        , "Switch to workspace ")
         , (W.shift     , shiftMask, "Move client to workspace ")
         ]
       , (i, k) <- concatMap (zip (XMonad.workspaces conf))
                             [[xK_1 .. xK_9] ++ [xK_0]]
       ]
    ++ [ ((m .|. modm, k), windows $ f i)
       | (i, k) <- zip (workspaces conf) [xK_1 ..]
       , (f, m) <-
         [(W.view, 0), (W.shift, shiftMask), (copy, shiftMask .|. controlMask)]
       ] ++
      [((m .|. modm, key), screenWorkspace sc >>= flip whenJust (windows . f))
          | (key, sc) <- zip [xK_r, xK_w] [0..]
          , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
