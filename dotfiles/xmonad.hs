import XMonad
import XMonad.Util.Run
import XMonad.Util.Paste

main = do
  xmonad $ def {modMask = myModMask, terminal = myTerminal, borderWidth = myBorderWidth
        }

myTerminal = "alacritty"
myModMask = mod1Mask
myBorderWidth = 5
-- myFocusFollowsMouse = True
                -- focusFollowsMouse = myFocusFollowsMouse




