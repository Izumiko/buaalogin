version     = "0.1.0"
author      = "Izumiko"
description = "CLI client for srun of BUAA"
license     = "MIT"

srcDir = "src"

namedBin["main"] = "buaalogin"

requires "nim >= 1.2.2", "hmac >= 0.2.0"
