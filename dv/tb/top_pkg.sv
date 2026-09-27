package top_pkg;
  parameter int TL_AW = 32;
  parameter int TL_DW = 32;
  parameter int TL_AIW = 8;
  parameter int TL_DIW = 8;
  parameter int TL_DUW = 4;
  parameter int TL_DBW = (TL_DW >> 3);
  parameter int TL_SZW = $clog2(TL_DBW);
  parameter int TL_AUW = 1;
endpackage : top_pkg

package prim_mubi_pkg;
  // Definitions of MuBi types
  typedef enum logic [3:0] {
    MuBi4False = 4'h6,
    MuBi4True  = 4'h9
  } mubi4_t;

  typedef enum logic [7:0] {
    MuBi8False = 8'h5A,
    MuBi8True  = 8'hA5
  } mubi8_t;

  typedef enum logic [11:0] {
    MuBi12False = 12'h5A6,
    MuBi12True  = 12'hA59
  } mubi12_t;

  typedef enum logic [15:0] {
    MuBi16False = 16'h5A5A,
    MuBi16True  = 16'hA5A5
  } mubi16_t;

  typedef enum logic [19:0] {
    MuBi20False = 20'h5A5A6,
    MuBi20True  = 20'hA5A59
  } mubi20_t;

  typedef enum logic [23:0] {
    MuBi24False = 24'h5A5A5A,
    MuBi24True  = 24'hA5A5A5
  } mubi24_t;

  typedef enum logic [27:0] {
    MuBi28False = 28'h5A5A5A6,
    MuBi28True  = 28'hA5A5A59
  } mubi28_t;

  typedef enum logic [31:0] {
    MuBi32False = 32'h5A5A5A5A,
    MuBi32True  = 32'hA5A5A5A5
  } mubi32_t;

  // Helper functions for 4-bit
  function automatic mubi4_t mubi4_or_hi(mubi4_t a, mubi4_t b);
    return (a == MuBi4True || b == MuBi4True) ? MuBi4True : MuBi4False;
  endfunction

  function automatic mubi4_t mubi4_and_hi(mubi4_t a, mubi4_t b);
    return (a == MuBi4True && b == MuBi4True) ? MuBi4True : MuBi4False;
  endfunction

  // Helper functions for 8-bit
  function automatic mubi8_t mubi8_or_hi(mubi8_t a, mubi8_t b);
    return (a == MuBi8True || b == MuBi8True) ? MuBi8True : MuBi8False;
  endfunction

  function automatic mubi8_t mubi8_and_hi(mubi8_t a, mubi8_t b);
    return (a == MuBi8True && b == MuBi8True) ? MuBi8True : MuBi8False;
  endfunction

  // Helper functions for 12-bit
  function automatic mubi12_t mubi12_or_hi(mubi12_t a, mubi12_t b);
    return (a == MuBi12True || b == MuBi12True) ? MuBi12True : MuBi12False;
  endfunction

  function automatic mubi12_t mubi12_and_hi(mubi12_t a, mubi12_t b);
    return (a == MuBi12True && b == MuBi12True) ? MuBi12True : MuBi12False;
  endfunction

  // Helper functions for 16-bit
  function automatic mubi16_t mubi16_or_hi(mubi16_t a, mubi16_t b);
    return (a == MuBi16True || b == MuBi16True) ? MuBi16True : MuBi16False;
  endfunction

  function automatic mubi16_t mubi16_and_hi(mubi16_t a, mubi16_t b);
    return (a == MuBi16True && b == MuBi16True) ? MuBi16True : MuBi16False;
  endfunction

  // Helper functions for 20-bit
  function automatic mubi20_t mubi20_or_hi(mubi20_t a, mubi20_t b);
    return (a == MuBi20True || b == MuBi20True) ? MuBi20True : MuBi20False;
  endfunction

  function automatic mubi20_t mubi20_and_hi(mubi20_t a, mubi20_t b);
    return (a == MuBi20True && b == MuBi20True) ? MuBi20True : MuBi20False;
  endfunction

  // Helper functions for 24-bit
  function automatic mubi24_t mubi24_or_hi(mubi24_t a, mubi24_t b);
    return (a == MuBi24True || b == MuBi24True) ? MuBi24True : MuBi24False;
  endfunction

  function automatic mubi24_t mubi24_and_hi(mubi24_t a, mubi24_t b);
    return (a == MuBi24True && b == MuBi24True) ? MuBi24True : MuBi24False;
  endfunction

  // Helper functions for 28-bit
  function automatic mubi28_t mubi28_or_hi(mubi28_t a, mubi28_t b);
    return (a == MuBi28True || b == MuBi28True) ? MuBi28True : MuBi28False;
  endfunction

  function automatic mubi28_t mubi28_and_hi(mubi28_t a, mubi28_t b);
    return (a == MuBi28True && b == MuBi28True) ? MuBi28True : MuBi28False;
  endfunction

  // Helper functions for 32-bit
  function automatic mubi32_t mubi32_or_hi(mubi32_t a, mubi32_t b);
    return (a == MuBi32True || b == MuBi32True) ? MuBi32True : MuBi32False;
  endfunction

  function automatic mubi32_t mubi32_and_hi(mubi32_t a, mubi32_t b);
    return (a == MuBi32True && b == MuBi32True) ? MuBi32True : MuBi32False;
  endfunction

endpackage : prim_mubi_pkg
