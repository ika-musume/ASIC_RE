/*
    Copyright (C) 2022 Sehyeon Kim(Raki)
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

module submdl_pla
(
    input   wire            i_A,
    input   wire            i_B,
    input   wire            i_C,
    input   wire            i_D,
    input   wire            i_E,
    input   wire            i_F,
    input   wire            i_G,
    input   wire            i_H,

    output  wire            o_S,
    output  wire            o_T,
    output  wire            o_U,
    output  wire            o_V,
    output  wire            o_W,
    output  wire            o_X,
    output  wire            o_Y,
    output  wire            o_Z
);

//internal wires
wire    A = i_A; //CMDREG.RDREQ
wire    B = i_B; //CMDREG.WRREQ
wire    C = i_C; //FSMSTAT.D0
wire    D = i_D; //FSMSTAT.D1
wire    E = i_E; //FSMSTAT.D2
wire    F = i_F; //F25/Q
wire    G = i_G; //FSMFLAGIN
wire    H = i_H; //SYS_ERR_FLAG


//AND array 1
wire    S36 =   &{    A, ~B,  C, ~D,  E, ~F,     ~H   };
wire    S44 =   &{   ~A,  B,             ~F, ~G       };
wire    S43 =   &{   ~A,  B, ~C, ~D,  E, ~F,     ~H   };
wire    R49 =   &{           ~C,  D, ~E,         ~H   };
wire    S42 =   &{   ~A,  B, ~C,  D,  E, ~F,     ~H   };
wire    R50 =   &{            C,  D, ~E,         ~H   };
wire    S41 =   &{    A, ~B,             ~F, ~G       };
wire    S29 =   &{   ~A, ~B,             ~F, ~G       };
wire    R36 =   &{            C,  D,  E,         ~H   };
wire    S37 =   &{   ~A, ~B,              F,  G       };

//misc
wire    S45 = S44 | S37; //~A
wire    R33 = A ^ B;

//AND array 2
wire    R35 =   &{               ~D, ~E,         ~H   } & S29;
wire    R32 =   &{   ~A,  B                           } & R36;
wire    S31 =   &{                           ~G       } & S43;
wire    R29 =   &{    A, ~B,             ~F           } & R36;
wire    S30 =   &{                           ~G       } & S36;
wire    S27 =                                             R49 & S29;
wire    S50 =   &{   ~A, ~B, ~C, ~D, ~E,          H   };
wire    S49 =   &{   ~A, ~B, ~C, ~D, ~E, ~F,  G, ~H   };
wire    S46 =                                             S44 & R50;
wire    S38 =   &{                            G       } & S36;
wire    T42 =   &{                           ~G       } & S42;
wire    T40 =   &{                            G       } & S43;
wire    S48 =                                             R49 & S41;
wire    S47 =                                             S44 & R49;
wire    R52 =                                             R50 & S41;
wire    S51 =   &{            C, ~D, ~E,         ~H   } & S45;
wire    T41 =   &{                            G       } & S42;
wire    R34 =                                             S29 & R36;
wire    R37 =   &{            C,  D,  E,          H   } & R33;
wire    R30 =   &{    A, ~B,              F           } & R36;
wire    S40 =   &{            C, ~D, ~E,          H   } & S29;

//OR array
wire    S28 = |{R35, R32, S31, R29, S30, S27};

assign  o_S  = ~(|{S50, S49, S46, S38, T42, T40, R52, T41, R34} | S28);
assign  o_T  = ~ S40;
assign  o_U  = ~|{S48, S47};

assign  o_V  = ~(|{S49, T42, T40, T41, R34, S40} | S28);
assign  o_W  = ~|{S38, S47};
assign  o_X  = ~|{S46, S38, R52};

assign  o_Y  = ~|{S49, S46, T42, S48, S47, S51, T41, R34, R37, R30};
assign  o_Z  = ~|{S38, T40, R52, T41, R34, R37, R30, S40};


//t = &{            C, ~D, ~E,          H   } &
//    &{   ~A, ~B,             ~F, ~G       };  //S29

//U = &{           ~C,  D, ~E,         ~H   } &
//    &{    A, ~B,             ~F, ~G       } |
//    &{   ~A,  B,             ~F, ~G       } &
//    &{           ~C,  D, ~E,         ~H   };

//T = &{   ~A, ~B,  C, ~D, ~E, ~F, ~G,  H   } | //00100001
//U = &{    A, ~B, ~C,  D, ~E, ~F, ~G, ~H   } | //10010000
//    &{   ~A,  B, ~C,  D, ~E, ~F, ~G, ~H   };  //01010000





endmodule