clear all
close all
clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FCS Surface Generator
% This is a script to generate a surface from FCS excitation rate data
% using Intensity as one axis, exposure time as another, and localization
% uncertainty as the third
%
% AJN 8/12/15
%
% 8/22/15 v 2 added photobleaching quantum yield support to model photobleaching
% 8/25/15 v 3 fixed detection efficiency and background contribution
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% User defined variables
int_col = 13; % This is the column from the excel data that the intensity is located
count_col = 11; % This is the column from the excel data that the adjusted counts / molecule/sec are located
bkgn_col = 10; % This is the column from the excel data that the avg background counts are located
flick_col = 24; % colomn in data where the flicker fraction occurs
max_time = .001;   % Max frame exposure in seconds
time_div = 100; % number of divisions of exposure time (correpsonds to number of data points)
PQY = 2.5*10^-5;    % Photobleaching quantum yield this is the total excitations, NOT photons detected
det_prob = 0.05; % detection efficiency

% Thompson Larson Webb related Variables
NA = 1.45; % NA of Lens used
n = 1.515; % Index of refraction of immersion media, can be water @ 1.33 or oil @ 1.515
wvlngth = 567; % Wavelength of light imaged in nm
q = 133;  % Pixel Size in nm
num_lens = 4; % Number of lenses in the system including the objective

%% File selection and loading
[fname, fpath] = uigetfile('*.xls', 'Select data file to analyze');  % forces the user to chose a .xls file
mast_file = xlsread([fpath,fname]);   % loads all xls data

% cherry pick relevant data of interest
intensities = mast_file(:,int_col);
counts_per_mol = mast_file(:,count_col);
bkgns = mast_file(:,bkgn_col);
flicks = mast_file(:,flick_col);

% Remove NaNs
counts_per_mol(isnan(intensities)) = [];
bkgns(isnan(intensities)) = [];
flicks(isnan(intensities)) = [];
intensities(isnan(intensities)) = [];
% clear data for proper memory management
% clear mast_file 

num_entry = numel(intensities); % find number of elements from which data will be taken

% Construction of grids to be used in calculation
[timegrid, countgrid] = meshgrid(max_time/time_div:max_time/time_div:max_time,counts_per_mol);
[nullgrid, bkgn_grid] = meshgrid(max_time/time_div:max_time/time_div:max_time,bkgns);
[nullgrid, flick_grid] = meshgrid(max_time/time_div:max_time/time_div:max_time,(1-flicks));
clear nullgrid

%% Photobleaching model
% Here we take the photobleaching quantum yield and calculate how many
% photons on average will a molecule give off before there is a 50% cahnce
% of photobleaching

NPQY = 1 - PQY;  % Chance of molecule to not photobleach on 1 absorbtion
ex_max = round(log(0.5)/log(NPQY)); % 50% chance of photobleach
% % ex_max = 1/PQY;                   % inverse of photobleach yield
% theta2 = asin(NA / n ); % double angle of cone of light collected by the lens
% sol_ang = 2*pi*(1-cos(theta2));  %solid angle of collected light
% col_prob = sol_ang/(4*pi);  % portion of solid angle of whole sphere of emitted light, which translates into probability of a photon being captured
% lens_eff = (1-glass_air)^(num_lens - 1);
% det_prob = col_prob * lens_eff;


N =timegrid.*countgrid; % number of photons expected without photobleaching


ex_tot = N./(flick_grid.*det_prob);
N_max = ex_max.*det_prob.*flick_grid;
[row col] = find(N > N_max);

for i = 1:numel(row)
    N(row(i),col(i)) = N_max(row(i),col(i));
end
xax = max_time/time_div:max_time/time_div:max_time;
% build diffraction information
r0 = 0.61 * wvlngth / NA; % 1 / e^2 radius of PSF
s = r0 /2; % e^-2 radius is 2 sigma, half that is std dev of psf required for TLW

%% TLW equation
lu2 = ((s^2+q^2/12)./(N))+((4*pi^0.5*s^3.*(timegrid.*bkgn_grid))./(q.*(N).^2));
lu = lu2.^0.5;  % loc uncertainty

[rowl coll] = find(lu == min(min(lu)));
%% Graphical Representation
f1 = figure('units','normalized','outerposition',[0 0 1 1]);
% surf(xax(coll-50:coll+50),intensities(rowl-3:rowl+3),lu(rowl-3:rowl+3,coll-50:coll+50));  
surf(xax,intensities,lu);  
xlabel('Frame exposure time');
ylabel('Intensity in kW/cm^2');
zlabel('Localization Uncertainty in nm')
set(gca,'YScale','log');
disp(['The minimum uncertainty is ' num2str(lu(rowl,coll)),'nm at ' num2str(xax(coll)), 's and ' num2str(intensities(rowl)), ' kw/cm^2']);