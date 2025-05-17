#!/usr/bin/env python3

from ctypes import cdll

lib = cdll.LoadLibrary("/System/Library/PrivateFrameworks/UniversalAccess.framework/UniversalAccess")
lib.UAGrayscaleSetEnabled(lib.UAGrayscaleIsEnabled() == 0)

