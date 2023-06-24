#-----------------------------------------------------------------------------
# This file is part of the 'Simple-ZCU670-Example'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'Simple-ZCU670-Example', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import axi_soc_ultra_plus_core as socCore
import surf.xilinx             as xil
import simple_zcu670_example   as rfsoc

class RFSoC(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

        self.add(socCore.AxiSocCore(
            offset       = 0x0000_0000,
            numDmaLanes  = 2,
            # expand       = True,
        ))

        self.add(xil.RfDataConverter(
            offset    = 0x9000_0000,
            enAdcTile = [False,False,True,False],
            enDacTile = [True,False,False,False],
            # expand    = True,
        ))

        self.add(rfsoc.Application(
            offset = 0xA000_0000,
            expand = True,
        ))
