%--------------------------------------------------------------------------
%                           SoftGNSS v3.0 BeiDou version
% 
% Copyright (C) Darius Plausinaitis and Dennis M. Akos
% Written by Darius Plausinaitis and Dennis M. Akos
% Updated and converted to scilab 5.4.1 by Artyom Gavrilov
% Beidou version is updated and converted to Matlab by Xiangyu Li
%--------------------------------------------------------------------------
%This program is free software; you can redistribute it and/or
%modify it under the terms of the GNU General Public License
%as published by the Free Software Foundation; either version 2
%of the License, or (at your option) any later version.
%
%This program is distributed in the hope that it will be useful,
%but WITHOUT ANY WARRANTY; without even the implied warranty of
%MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%GNU General Public License for more details.
%
%You should have received a copy of the GNU General Public License
%along with this program; if not, write to the Free Software
%Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
%USA.
%--------------------------------------------------------------------------
%
%Script initializes settings and environment of the software receiver.
%Then the processing is started.

% Clean up the environment first =========================================
clear; close all; clc;

format ('compact');
format ('long', 'g');

%stacksize('max');
%--- Include folders with functions ---------------------------------------
addpath include             % The software receiver functions
addpath geoFunctions        % Position calculation related functions

% Print startup ==========================================================

fprintf(['\n','Welcome to:  softGNSS\n'])
fprintf('*******************************************************\n\n');
% Initialize constants, settings =========================================
settings = initSettings();

% Generate plot of raw data and ask if ready to start processing =========
try
  fprintf('Probing data (%s)...\n', settings.fileName);
  probeData(settings);
catch
  % There was an error, print it and exit
  errStruct = lasterror;
  disp(errStruct.message);
  disp('  (run setSettings or change settings in initSettings.sci to reconfigure)');
  return;
end
    
fprintf('  Raw IF data plotted \n');
fprintf('  (run setSettings or change settings in initSettings.sci to reconfigure)');
fprintf(' ');
%gnssStart = input('Enter {1} to initiate GNSS processing or {0} to exit : ');
gnssStart = 1;
if (gnssStart == 1)
  fprintf(' ');
  %start things rolling...
  postProcessing
end
