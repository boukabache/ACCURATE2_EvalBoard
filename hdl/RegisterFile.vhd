--! @file RegisterFile.vhd
--! @brief Module to store the temporary configuration of the DAC and ACCURATE
--! coming from the UART interface. It also drives the configuration signals.
--
--! Reset can be configured to either reset the configuration to default values
--! or to all zeros.
--
--! The address map is as follows:
--! 0x00 - 0x07: DAC configuration voltages
--! |-> 0x00: vOutA
--! |-> 0x01: vOutB
--! |-> 0x02: vOutC
--! |-> 0x03: vOutD
--! |-> 0x04: vOutE
--! |-> 0x05: vOutF
--! |-> 0x06: vOutG
--! |-> 0x07: vOutH
--! 0x08 - 0x17: ACCURATE configuration
--! |-> 0x08: chargeQuantaCP1
--! |-> 0x09: chargeQuantaCP2
--! |-> 0x0A: chargeQuantaCP3
--! |-> 0x0B: cooldownMinCP1
--! |-> 0x0C: cooldownMaxCP1
--! |-> 0x0D: cooldownMinCP2
--! |-> 0x0E: cooldownMaxCP2
--! |-> 0x0F: cooldownMinCP3
--! |-> 0x10: cooldownMaxCP3
--! |-> 0x11: resetOTA
--! |-> 0x12: tCharge
--! |-> 0x13: tInjection
--! |-> 0x14: disableCP1
--! |-> 0x15: disableCP2
--! |-> 0x16: disableCP3
--! |-> 0x17: singlyCPActivation
--! 0x18 - 0x18: uart management
--! |-> 0x18: if '1', allow streaming of data, disallow (n)ack to rx requests

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IOPkg.all;
use work.accurateConfigPkg.all;
use work.configPkg.all;

entity RegisterFile is
    port (
        clk     : in  std_logic;     -- Clock input
        rst     : in  std_logic;     -- Reset input

        -- DAC configuration signals
        dacConfigxDO : out dacConfigRecordT;

        -- ACCURATE configuration signals
        accurateConfigxDO      : out accurateRecordT;
        accurateConfigValidxDO : out std_logic;

        -- Enable data streaming, hence disallowing (n)ack response to rx uart request
        enableDataStreamUartxDO : out std_logic;

        -- Input port
        addressxDI   : in unsigned(registerFileAddressWidthC-1 downto 0); -- Address input
        dataxDI      : in std_logic_vector(registerFileDataWidthC-1 downto 0); -- Data input
        dataValidxDI : in std_logic; -- Data valid input
        -- Single cycle '1' if request does not make sense (address out of range, data out of range)
        requestErrorxDO : out std_logic

    );
end entity RegisterFile;


architecture rtl of RegisterFile is
    type memoryT is
        array ( 0 to ((2 ** registerFileAddressWidthC) - 1)) of
        std_logic_vector(registerFileDataWidthC - 1 downto 0);

    constant memoryInitialStateC : memoryT := (
        0  => std_logic_vector(resize(dacConfigRecordTDefault.vOutA, registerFileDataWidthC)),
        1  => std_logic_vector(resize(dacConfigRecordTDefault.vOutB, registerFileDataWidthC)),
        2  => std_logic_vector(resize(dacConfigRecordTDefault.vOutC, registerFileDataWidthC)),
        3  => std_logic_vector(resize(dacConfigRecordTDefault.vOutD, registerFileDataWidthC)),
        4  => std_logic_vector(resize(dacConfigRecordTDefault.vOutE, registerFileDataWidthC)),
        5  => std_logic_vector(resize(dacConfigRecordTDefault.vOutF, registerFileDataWidthC)),
        6  => std_logic_vector(resize(dacConfigRecordTDefault.vOutG, registerFileDataWidthC)),
        7  => std_logic_vector(resize(dacConfigRecordTDefault.vOutH, registerFileDataWidthC)),

        8  => std_logic_vector(resize(accurateRecordTDefault.chargeQuantaCP1, registerFileDataWidthC)),
        9  => std_logic_vector(resize(accurateRecordTDefault.chargeQuantaCP2, registerFileDataWidthC)),
        10 => std_logic_vector(resize(accurateRecordTDefault.chargeQuantaCP3, registerFileDataWidthC)),
        11 => std_logic_vector(resize(accurateRecordTDefault.cooldownMinCP1, registerFileDataWidthC)),
        12 => std_logic_vector(resize(accurateRecordTDefault.cooldownMaxCP1, registerFileDataWidthC)),
        13 => std_logic_vector(resize(accurateRecordTDefault.cooldownMinCP2, registerFileDataWidthC)),
        14 => std_logic_vector(resize(accurateRecordTDefault.cooldownMaxCP2, registerFileDataWidthC)),
        15 => std_logic_vector(resize(accurateRecordTDefault.cooldownMinCP3, registerFileDataWidthC)),
        16 => std_logic_vector(resize(accurateRecordTDefault.cooldownMaxCP3, registerFileDataWidthC)),
        17 => (0 => accurateRecordTDefault.resetOTA, others => '0'),
        18 => std_logic_vector(resize(accurateRecordTDefault.tCharge, registerFileDataWidthC)),
        19 => std_logic_vector(resize(accurateRecordTDefault.tInjection, registerFileDataWidthC)),
        20 => (0 => accurateRecordTDefault.disableCP1, others => '0'),
        21 => (0 => accurateRecordTDefault.disableCP2, others => '0'),
        22 => (0 => accurateRecordTDefault.disableCP3, others => '0'),
        23 => (0 => accurateRecordTDefault.singlyCPActivation, others => '0'),
        24 => (0 => '1', others => '0'),
        others => (others => '0')
    );

    signal regFilexDN, regFilexDP : memoryT := memoryInitialStateC;

    signal requestErrorxDP, requestErrorxDN : std_logic := '0';
begin

    -----------------
    -- INPUT
    -----------------
    inputP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                regFilexDP <= memoryInitialStateC;
            else
                regFilexDP <= regFilexDN;
                requestErrorxDP <= requestErrorxDN;
            end if;
        end if;
    end process inputP;

    regFileP: process(all)
    begin
        requestErrorxDN <= '1';
        regFilexDN <= regFilexDP;
        if dataValidxDI = '1' then
            if addressxDI >= to_unsigned(registerFileAddressWidthC - 1, addressxDI'length) then
                requestErrorxDN <= '1';
            else
                regFilexDN(to_integer(addressxDI)) <= dataxDI;
            end if;
        end if;
    end process regFileP;

    -----------------
    -- OUTPUT
    -----------------
    dacConfigxDO.vOutA <= unsigned(regFilexDP(0)(dacConfigxDO.vOutA'range));
    dacConfigxDO.vOutB <= unsigned(regFilexDP(1)(dacConfigxDO.vOutB'range));
    dacConfigxDO.vOutC <= unsigned(regFilexDP(2)(dacConfigxDO.vOutC'range));
    dacConfigxDO.vOutD <= unsigned(regFilexDP(3)(dacConfigxDO.vOutD'range));
    dacConfigxDO.vOutE <= unsigned(regFilexDP(4)(dacConfigxDO.vOutE'range));
    dacConfigxDO.vOutF <= unsigned(regFilexDP(5)(dacConfigxDO.vOutF'range));
    dacConfigxDO.vOutG <= unsigned(regFilexDP(6)(dacConfigxDO.vOutG'range));
    dacConfigxDO.vOutH <= unsigned(regFilexDP(7)(dacConfigxDO.vOutH'range));

    accurateConfigxDO.chargeQuantaCP1    <= signed(regFilexDP( 8)(accurateConfigxDO.chargeQuantaCP1'range));
    accurateConfigxDO.chargeQuantaCP2    <= signed(regFilexDP( 9)(accurateConfigxDO.chargeQuantaCP2'range));
    accurateConfigxDO.chargeQuantaCP3    <= signed(regFilexDP(10)(accurateConfigxDO.chargeQuantaCP3'range));
    accurateConfigxDO.cooldownMinCP1     <= unsigned(regFilexDP(11)(accurateConfigxDO.cooldownMinCP1'range));
    accurateConfigxDO.cooldownMaxCP1     <= unsigned(regFilexDP(12)(accurateConfigxDO.cooldownMaxCP1'range));
    accurateConfigxDO.cooldownMinCP2     <= unsigned(regFilexDP(13)(accurateConfigxDO.cooldownMinCP2'range));
    accurateConfigxDO.cooldownMaxCP2     <= unsigned(regFilexDP(14)(accurateConfigxDO.cooldownMaxCP2'range));
    accurateConfigxDO.cooldownMinCP3     <= unsigned(regFilexDP(15)(accurateConfigxDO.cooldownMinCP3'range));
    accurateConfigxDO.cooldownMaxCP3     <= unsigned(regFilexDP(16)(accurateConfigxDO.cooldownMaxCP3'range));
    accurateConfigxDO.resetOTA           <= regFilexDP(17)(0);
    accurateConfigxDO.tCharge            <= unsigned(regFilexDP(18)(accurateConfigxDO.tCharge'range));
    accurateConfigxDO.tInjection         <= unsigned(regFilexDP(19)(accurateConfigxDO.tInjection'range));
    accurateConfigxDO.disableCP1         <= regFilexDP(20)(0);
    accurateConfigxDO.disableCP2         <= regFilexDP(21)(0);
    accurateConfigxDO.disableCP3         <= regFilexDP(22)(0);
    accurateConfigxDO.singlyCPActivation <= regFilexDP(23)(0);

    enableDataStreamUartxDO <= regFilexDP(24)(0);

    accurateConfigValidxDO <= '1';

    requestErrorxDO <= requestErrorxDP;
end architecture rtl;
