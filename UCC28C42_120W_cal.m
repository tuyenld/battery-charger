%% Requirements
% VIN Input Voltage 85 115/230 265 VRMS
% fLINE Line Frequency 47 50/60 63 Hz
% VOUT Output Voltage IOUT(min) ≤ IOUT ≤ IOUT(max) 11.75 12 12.25 V
% VRIPPLE Output Ripple Voltage: 100 mVpp
% IOUT Output Current: 0.4 A
% fSW Switching Frequency: 100 kHz
% η Efficiency: 85%

clear; clc;
%% Input
V_in_min = 85; % RMS value of the minimum AC input voltage
V_in_max = 265; % RMS value of the maximum AC input voltage
f_line_min = 47; % minimum line freq.
P_out = 120; % output power
V_out = 20; % output voltage
eff = 0.85; % converter efficiency

f_sw = 110 * 1e3; % ???

% To minimize the cost of the system, 
% a readily available 650-V MOSFET is selected
V_ds_mosfet = 650; 

V_bias = 12; % VCC operating voltage for the UCC28C42

% The forward voltage drop 
% of this diode is estimated to be equal to 0.6 V
V_diode_f = 0.6;

V_bulk_min = 75; % ??? page 23 / 57
R_g = 10; % 9.76Ohm from WEBENCH % 9.2.2.6 Gate Drive Resistor

%% Note
cprintf('err',     'You need to change soft start circuit\n');

%% Calculation

I_out = P_out / V_out;
R_out = V_out^2 / P_out;

%% 9.2.2.1 Input Bulk Capacitor and Minimum Bulk Voltage
P_in = P_out / eff;
E = exp(1);
C_in_num = 2 * P_in * (0.25 + 1/pi * asin(V_bulk_min/(sqrt(2) * V_in_min)));
C_in_denom = (2 * V_in_min^2 - V_bulk_min^2) * f_line_min;
C_in = C_in_num/C_in_denom;

fprintf ("[min][Change me] Input Bulk Capacitor [C_in:%f us] \n", C_in * 1e6);
C_in = 320 * 1e-6;
fprintf ("\t-- Input Bulk Capacitor [C_in:%f us] \n", C_in * 1e6);
%% 9.2.2.2 Transformer Turns Ratio and Maximum Duty Cycle

V_bulk_max = sqrt(2) * V_in_max;

% Derating the maximum voltage stress on the drain to 
% 80 % of its rated value 
% and allowing for a leakage inductance voltage spike 
% of up to 30% of the maximum bulk input voltage, 
% the reflected output voltage should be less than 
V_reflected = 0.8 * (V_ds_mosfet - 1.3 * V_bulk_max);

% The maximum primary to secondary transformer turns ratio
N_ps = V_reflected / V_out;
fprintf ("[max][Change me] Primary to secondary transf. turns ratio [N_PS: %f] \n" ...
    , N_ps);
N_ps = 6;
fprintf ("\t-- Primary to secondary transf. turns ratio [N_PS: %f] \n" ...
    , N_ps);

% The primary to auxiliary turns ratio
N_pa = N_ps * V_out / V_bias;
fprintf ("[avg][Change me] Primary to auxiliary transf. turns ratio [N_PA:%f] \n" ...
    , N_pa);
N_pa = 10;
fprintf ("\t-- Primary to auxiliary transf. turns ratio [N_PA:%f] \n" ...
    , N_pa);
% output diode calculation is moved bellow

D_max_num = N_ps * (V_out + V_diode_f);
D_max_denom = V_bulk_min + N_ps * (V_out + V_diode_f);
D_max = D_max_num / D_max_denom;
fprintf ("[min][Verify] maximum duty cycle of the IC %f \n" ...
    , D_max * 100);
fprintf ("\t-- UCC28C42 can work from 0- 100 %% dutycle \n");

%% 9.2.2.3 Transformer Inductance and Peak Currents

% LP for a CCM flyback
L_p_num = (V_bulk_min ^ 2) * (N_ps * V_out / (V_bulk_min + N_ps * V_out))^2;
L_p_denom = 2 * 0.1 * P_in * f_sw;
L_p = L_p_num / L_p_denom;

% Critical inductance
L_P_crit_num = R_out * N_ps^2 * V_in_max^2;
L_P_crit_denom = 2 * f_sw * (V_in_max + V_out * N_ps) ^2;
L_P_crit = L_P_crit_num / L_P_crit_denom;
fprintf ("[  ~][Change me] Transf. inductance should be approximately " + ...
    "[L_P:%f mH] >  [L_Pcrit:%f mH]\n", L_p * 1e3, L_P_crit * 1e3);
L_p = 0.7 * 1e-3;
fprintf ("\t-- Transf. inductance should be [L_P:%f mH]\n" ...
    , L_p * 1e3);

% The peak current in the primary-side MOSFET of a CCM flyback
I_mosfet_peak_op1_num = P_in;
I_mosfet_peak_op1_denom = V_bulk_min * N_ps * V_out / (V_bulk_min + N_ps * V_out);
I_mosfet_peak_op1 = I_mosfet_peak_op1_num / I_mosfet_peak_op1_denom;
I_mosfet_peak_op2_num = V_bulk_min * N_ps * V_out;
I_mosfet_peak_op2_denom = 2 * L_p * (V_bulk_min + N_ps * V_out) * f_sw;
I_mosfet_peak_op2 = I_mosfet_peak_op2_num / I_mosfet_peak_op2_denom;
I_mosfet_peak = I_mosfet_peak_op1 + I_mosfet_peak_op2;
fprintf ("[][x] The peak current in the primary-side MOSFET %f \n" ...
    , I_mosfet_peak);

% I_mosfet_RMS ??? don't need to cal
I_mosfet_RMS_square = D_max^3 / 3 * (V_bulk_min / (L_p * f_sw))^2 ...
    - D_max ^2 * I_mosfet_peak * V_bulk_min / (L_p * f_sw) + (D_max * I_mosfet_peak ^2);
I_mosfet_RMS = sqrt(I_mosfet_RMS_square);
fprintf ("[][x] The RMS current in the primary-side MOSFET %f \n" ...
    , I_mosfet_RMS);
fprintf("\t-- You need to choose the MOSFET [IRFB9N65A] \n")

% output diode calculation
V_diode = V_bulk_max / N_ps + V_out;
% fprintf ("[min][Change me] Schottky diode with a rated blocking voltage %f \n" ...
%     , V_diode);
I_diode_peak = N_ps * I_mosfet_peak;
% The diode average current is equal to the total output current
I_diode_avg = I_out;
fprintf ("[][x] Choose diode I_AVG [%f]; I_peak [%f] V_diode [%f]\n" ...
    , I_diode_avg, I_diode_peak, V_diode);
fprintf("\t-- You need to choose the output diode [48CTQ060-1] Schottky diode, 60V \n");
fprintf("\t-- Don't forget to change V_diode_f accordingly \n");

%% 9.2.2.4 Output Capacitor
C_out_num = I_out * N_ps * V_out / (V_bulk_min + N_ps * V_out);
C_out_denom = 0.1 / 100 * V_out * f_sw;
C_out = C_out_num / C_out_denom;
fprintf ("[min][Change me] Output Capacitor [C_out:%f uF] \n" ...
    , C_out * 1e6);
C_out = 1.7 * 1e-3;
fprintf ("\t-- Output Capacitor [C_out:%f uF] \n" ...
    , C_out * 1e6);

cprintf('hyper',   'Note: ');
fprintf("You need to get ESR of the cap. from datasheet \n");
R_ESR = 43 * 1e-3;

%% 9.2.2.5 Current Sensing Network

% Without RP, RCS sets the maximum peak current in the transformer primary 
% based on the maximum amplitude of the ISENSE pin, 
% which is specified to be 1 V. 
% To achieve 1.36-A primary side peak current, 
% a 0.75-Ω resistor is chosen for RCS.
R_cs = 1 / I_mosfet_peak;
fprintf("[Change me] Current sense [R_CS:%f] \n", R_cs);
R_cs = 0.3;
fprintf("\t-- Current sense resistor [R_CS:%f] \n", R_cs);

%% 9.2.2.6 Gate Drive Resistor
fprintf ("[?? Change] Gate drive resistor [R_G: %d] 9.76Ohm from WEBENCH \n", R_g);

%% 9.2.2.7 VREF Capacitor
C_verf = 1 * 1e-6; 
fprintf ("[No change] VREF Capacitor [C_VREF: %d uF - 16V -  ceramic] " + ...
    "place as close as possible to VREF and GND \n", C_verf);

%% 9.2.2.8 RT/CT
% 15.4 kΩ and 1000 pF were selected for RRT and CCT 
% to operate at f_sw = 110-kHz
C_ct = 1000 * 1e-12;
R_rt = 15.4 * 1e3;
fprintf ("[No change if you keep f_sw constant] RT/CT [R_CT: %d, C_CT: %d]\n" ...
    ,R_rt, C_ct);

%% 9.2.2.9 Start-Up Circuit
% trade-off between power loss and start-up time
R_start = 420 * 1e3; % two 210-kΩ resistors in series
fprintf ("[No change] Start-up circuit [R_START: %d kOhm] two %d kOhm in series\n", R_start / 1e3, R_start/2 / 1e3);
fprintf ("For faster start-up, the bulk capacitor value may be decreased " + ...
    "or the RSTART resistor modified to a lower value. \n")

%% 9.2.2.10 Voltage Feedback Compensation
fprintf ("===== \n Voltage Feedback Compensation \n======\n");

% 9.2.2.10.1 Power Stage Poles and Zeroes
A_CS = 3;
t_L = 2 * L_p *f_sw / (R_out * N_ps^2);
M = V_out * N_ps / V_bulk_min;

% DC open-loop gain
G_O_demom = R_cs * A_CS * ((1-D_max)^2/t_L + 2 * M + 1);
G_O_num = R_out * N_ps;
G_O = G_O_num / G_O_demom;
fprintf("Open-loop gain G_O = %f [%f dB] \n", G_O, 20 * log10(G_O));

% A CCM flyback has two zeroes that are of interest
w_ESRz = 1 / (R_ESR * C_out);
f_ESRz = w_ESRz / (2 * pi);
fprintf("Left-half plane zero: %f kHz \n", f_ESRz / (1e3));

w_RHPz = R_out * (1-D_max)^2 * N_ps^2 / (L_p * D_max);
f_RHPz = w_RHPz / (2 * pi);
fprintf("Right-half plane f_RHPz = %f kHz\n", f_RHPz / 1e3);

% The power stage has one dominate pole, ωP1
w_P1_num = (1-D_max)^3/t_L + 1 + D_max;
w_P1_denom = R_out * C_out;
w_P1 = w_P1_num / w_P1_denom;
f_P1 = w_P1 / (2 * pi);
w_P2 = pi * f_sw;
f_P2 = f_sw / 2;
fprintf("Poles P1[%f]Hz, P2[%f]kHz \n", f_P1, f_P2/(1e3));

% 9.2.2.10.2 Slope Compensation
M_c = (1/pi + 0.5)/(1-D_max); % slope compensation factor
S_n = V_in_min * R_cs / L_p; % inductor rising slope
S_e = (M_c - 1) * S_n; % compensation slope
fprintf("[S_n is wrong??]Compensation slope S_e[%f], S_n[%f] M_c[%f]\n", S_e, S_n, M_c);

t_ON_min = D_max / f_sw;
V_OSC = 1.7;
S_OSC = V_OSC / t_ON_min;
R_RAMP = 24.9 * 1e3;
R_csf = R_RAMP / (S_OSC/S_e - 1);
fprintf("[] Sensor resistor R_csf[%f] kOhm, S_OSC[%f] \n", R_csf / 1e3, S_OSC);

%% 9.2.2.5 Current Sensing Network [moved here] because of R_csf
C_csf = 100 * 1e-12;
R_p = 0; % optional
V_ref = 1; % ???
% Once RP is added, adjust the current sense resistor, RCS, accordingly.
V_offset = R_csf * V_ref / (R_csf + R_p);
fprintf ("[???][???] Current Sensing Network \n");

%% 9.2.2.10.4 Compensation Loop
f_bw = f_RHPz / 4;
fprintf("[] Bandwidth of a CCM flyback f_bw[%f kHz] \n", f_bw / 1e3);

I_FB_ref = 1e-3;
REF_TL431 = 2.495; % The TL431 reference voltage, REFTL431, has a typical value of 2.495 V
R_FBU = (V_out - REF_TL431)/I_FB_ref; % top divider resistor
R_FBB = REF_TL431 / (V_out - REF_TL431) * R_FBU;

fprintf("[] Top divider resistor R_FBU[%f kOhm]; R_FBB[%f kOhm] \n", ...
    R_FBU / 1e3, R_FBB / 1e3);

% For good phase margin, a compensator zero, fCOMPz, 
% is needed and should be placed at 1/10th the desired bandwidth:
f_COMPz = f_bw / 10; 
w_COMPz = 2 * pi * f_COMPz;
C_COMPz = 0.01 * 1e-12;
R_COMPz = 1 / (w_COMPz * C_COMPz);

