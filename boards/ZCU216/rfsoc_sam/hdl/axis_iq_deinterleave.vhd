-------------------------------------------------------------------------------
-- axis_iq_deinterleave
--
-- ZCU216 (ZU49DR) port of rfsoc_sam.
--
-- The ZCU216 RF-ADC tiles pack I/Q complex samples onto a SINGLE AXI4-Stream
-- port (rfdc/mXY_axis), unlike the ZCU208 (ZU48DR) which exposes separate
-- real and imaginary AXI4-Stream ports directly from the RFDC IP. The
-- existing strath-sdr decimator IP (xsg_bwselector, packaged from a fixed
-- System Generator export) expects two separate 128-bit streams and cannot
-- be reparameterised without the original Simulink/System Generator model,
-- which is not available in this repository. This module bridges the gap by
-- splitting the RFDC's packed stream into separate real/imaginary streams.
--
-- Per AMD PG269 ("Zynq UltraScale+ RFSoC RF Data Converter", v2.6), a single
-- mXY_axis port carrying SAMPLES complex pairs per clock packs them as
-- consecutive 2*SAMPLE_BITS-wide {I,Q} pairs, sample index 0 (earliest in
-- time) in the least significant bits, I above Q within each pair. THIS
-- ORDERING WAS NOT independently confirmed against the primary PG269 tables
-- (only secondary/search-derived sources) -- verify against real hardware
-- (a known test tone should appear at the expected sign/frequency, not
-- mirrored) and flip the SAMPLE0_AT_LSB / I_IN_UPPER_HALF generics below
-- if it is not.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity axis_iq_deinterleave is
  generic (
    SAMPLES          : integer := 6;     -- complex (I/Q) sample pairs per clock
    SAMPLE_BITS       : integer := 16;    -- bits per I or per Q sample
    SAMPLE0_AT_LSB    : boolean := true;  -- sample index 0 in TDATA[low bits] if true
    I_IN_UPPER_HALF   : boolean := true   -- within a pair, I above Q if true
  );
  port (
    aclk              : in  std_logic;
    aresetn           : in  std_logic;

    s_axis_tvalid     : in  std_logic;
    s_axis_tready     : out std_logic;
    s_axis_tdata      : in  std_logic_vector(SAMPLES*2*SAMPLE_BITS-1 downto 0);

    m_axis_re_tvalid  : out std_logic;
    m_axis_re_tready  : in  std_logic;
    m_axis_re_tdata   : out std_logic_vector(SAMPLES*SAMPLE_BITS-1 downto 0);

    m_axis_im_tvalid  : out std_logic;
    m_axis_im_tready  : in  std_logic;
    m_axis_im_tdata   : out std_logic_vector(SAMPLES*SAMPLE_BITS-1 downto 0)
  );
end entity axis_iq_deinterleave;

architecture rtl of axis_iq_deinterleave is

  -- source pair index (0 = LSB pair) for logical sample position k
  function pair_index(k : integer) return integer is
  begin
    if SAMPLE0_AT_LSB then
      return k;
    else
      return SAMPLES - 1 - k;
    end if;
  end function;

begin

  gen_split : for k in 0 to SAMPLES-1 generate
    constant PAIR_LO : integer := pair_index(k) * 2 * SAMPLE_BITS;
    constant I_LO     : integer := PAIR_LO + SAMPLE_BITS;
    constant Q_LO     : integer := PAIR_LO;
  begin

    gen_i_upper : if I_IN_UPPER_HALF generate
      m_axis_re_tdata((k+1)*SAMPLE_BITS-1 downto k*SAMPLE_BITS) <=
        s_axis_tdata(I_LO+SAMPLE_BITS-1 downto I_LO);
      m_axis_im_tdata((k+1)*SAMPLE_BITS-1 downto k*SAMPLE_BITS) <=
        s_axis_tdata(Q_LO+SAMPLE_BITS-1 downto Q_LO);
    end generate;

    gen_i_lower : if not I_IN_UPPER_HALF generate
      m_axis_im_tdata((k+1)*SAMPLE_BITS-1 downto k*SAMPLE_BITS) <=
        s_axis_tdata(I_LO+SAMPLE_BITS-1 downto I_LO);
      m_axis_re_tdata((k+1)*SAMPLE_BITS-1 downto k*SAMPLE_BITS) <=
        s_axis_tdata(Q_LO+SAMPLE_BITS-1 downto Q_LO);
    end generate;

  end generate gen_split;

  -- Purely combinational bit-slicing: valid/ready pass straight through,
  -- both output streams always move together with the input.
  s_axis_tready    <= m_axis_re_tready and m_axis_im_tready;
  m_axis_re_tvalid <= s_axis_tvalid;
  m_axis_im_tvalid <= s_axis_tvalid;

end architecture rtl;
