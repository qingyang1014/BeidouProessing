function [navSolutions, eph] = postNavigation(trackResults, settings)
%Function calculates navigation solutions for the receiver (pseudoranges,
%positions). At the end it converts coordinates from the WGS84 system to
%the UTM, geocentric or any additional coordinate system.
%
%[navSolutions, eph] = postNavigation(trackResults, settings)
%
%   Inputs:
%       trackResults    - results from the tracking function (structure
%                       array).
%       settings        - receiver settings.
%   Outputs:
%       navSolutions    - contains measured pseudoranges, receiver
%                       clock error, receiver coordinates in several
%                       coordinate systems (at least ECEF and UTM).
%       eph             - received ephemerides of all SV (structure array).

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

% Check is there enough data to obtain any navigation solution ===========

%Local variables (to speed up code, bacause working with structs is slow):
%trkRslt_I_P = zeros(size(trackResults, 2), (settings.msToProcess - settings.skipNumberOfFirstBits));
% for i = 1:size(trackResults, 2)
%     trkRslt_status(i)   = trackResults.status(i);
%     trkRslt_I_P(i,:)    = trackResults(i).I_P((settings.skipNumberOfFirstBits+1):end);
%     trkRslt_PRN(i)      = trackResults(i).PRN;
%     absoluteSample(i,:) = trackResults(i).absoluteSample((settings.skipNumberOfFirstBits+1):end);
% end

set_numberOfChnls       = settings.numberOfChannels;
set_c                   = settings.c;
set_navSolPeriod        = settings.navSolPeriod;
set_elevationMask       = settings.elevationMask;
set_useTropCorr         = settings.useTropCorr;
set_samplesPerCode      = round(settings.samplingFreq / ...
    (settings.codeFreqBasis / settings.codeLength));
set_dataTypeSizeInBytes = settings.dataTypeSizeInBytes ;
%Local variables - end.

svnCount = sum([trackResults.status] ~= '-');

 if (settings.mstoprocess < 39000) || (svncount < 4)
     % show the error message and exit
    fprintf('record is too short or too few satellites tracked. exiting!\n');
     navsolutions = [];
     eph          = [];
     return
 end

% Find time marks start positions ==========================================
[subFrameStart, activeChnList] = findSubframeStart(trackResults, settings);
%pause;
% Decode ephemerides =====================================================
for channelNr = activeChnList
    
    %Add condition for the case of weak signal (Not all nav data is available):
    delFromActiveChnList = [];
   if (subFrameStart(channelNr) + 30000 -1) > length(trackResults(channelNr).I_P)
        delFromActiveChnList = [delFromActiveChnList channelNr];
        %activeChnList = setdiff(activeChnList, channelNr);
        %stringStart(channelNr) = []
        %continue;
    else
        %--- Copy 5 subframes long record from tracking output ---------------
         navBitsSamples = trackResults(channelNr).I_P(subFrameStart(channelNr) : ...
            subFrameStart(channelNr) + (30000) -1)';
        %pause;
        %--- Convert prompt correlator output to +-1 ---------
        navBitsSamples = sign(navBitsSamples');
        %--- Decode data and extract ephemeris information ---
        [eph(trkRslt_PRN(channelNr)), SOW(trkRslt_PRN(channelNr))] = ephemeris(navBitsSamples);
        
        %--- Exclude satellite if it does not have the necessary nav data -----
        % we will check existence of at least one variable from each
        % navigation string. It would be better to check existence of all variable
        % but in this case the condition will be too huge and unclear!
        if (isempty(eph(trackResults(channelNr).PRN).IODC) || ...
                isempty(eph(trackResults(channelNr).PRN).M_0) || ...
                isempty(eph(trackResults(channelNr).PRN).i_0) );
            
            %--- Exclude channel from the list (from further processing) ------
            %activeChnList = setdiff(activeChnList, channelNr);
            delFromActiveChnList = [delFromActiveChnList channelNr];
        end
        
        %--- Exclude satellite if it has MSB of health flag set:
        if ( eph(trackResults(channelNr).PRN).SatH1 == 1 )
            %activeChnList = setdiff(activeChnList, channelNr);
            %/delFromActiveChnList = [delFromActiveChnList channelNr];%temporary disable...
        end
    end
end
%pause;
%/activeChnList(delFromActiveChnList) = [];%temporary disable
%/subFrameStart(delFromActiveChnList) = [];%temporary disable

% Check if the number of satellites is still above 3 =====================

%2014-03-30 add to analyse the results
fprintf('activeChnlist:');
disp(activeChnList);

if (isempty(activeChnList) || (size(activeChnList, 2) < 4))
    % Show error message and exit
    fprintf('Too few satellites with ephemeris data for postion calculations. Exiting!\n');
    navSolutions = [];
    eph          = [];
    return
end
%
% Initialization =========================================================

% Set the satellite elevations array to INF to include all satellites for
% the first calculation of receiver position. There is no reference point
% to find the elevation angle as there is no receiver position estimate at
% this point.
satElev  = inf(1,  settings.numberOfChannels);

% Save the active channel list. The list contains satellites that are
% tracked and have the required ephemeris data. In the next step the list
% will depend on each satellite's elevation angle, which will change over
% time.
readyChnList = activeChnList;

%/transmitTime = SOW;
%pause;
transmitTime = SOW(trkRslt_PRN(activeChnList(1)));%+60*12.082;
%pause;
%##########################################################################
%#   Do the satellite and receiver position calculations                  #
%##########################################################################

% Initialization of current measurement ==================================
for currMeasNr = 1:fix((settings.msToProcess - max(subFrameStart) -...
    settings.skipNumberOfFirstBits) / ...
        settings.navSolPeriod)
    % Exclude satellites, that are belove elevation mask
    %/activeChnList = intersect(find(satElev >= settings.elevationMask), ...
    %/                          readyChnList);
    
    % Save list of satellites used for position calculation
    navSolutions.channel.SVN(activeChnList, currMeasNr) =trackResults.PRN(activeChnList);
    
    % These two lines help the skyPlot function. The satellites excluded
    % do to elevation mask will not "jump" to possition (0,0) in the sky
    % plot.
    navSolutions.channel.el(:, currMeasNr) = nan( settings.numberOfChannels, 1);
    navSolutions.channel.az (:, currMeasNr) = nan( settings.numberOfChannels, 1);
    
    % Find pseudoranges ======================================================
    navSolutions.channel.rawP  (:, currMeasNr) = calculatePseudoranges(...
         settings.numberOfChannels, set_samplesPerCode, ...
         trackResults(i).absoluteSample((settings.skipNumberOfFirstBits+1):end),...
        settings.c, set_dataTypeSizeInBytes, ...
        subFrameStart + settings.navSolPeriod * (currMeasNr-1), activeChnList)';
    
    % Find satellites positions and clocks corrections =======================
    [satPositions, satClkCorr] = satpos(transmitTime, ...
        [trackResults(activeChnList).PRN], ...
        eph, settings);
    %pause;
    % Find receiver position =================================================
    
    % 3D receiver position can be found only if signals from more than 3
    % satellites are available
    if length(activeChnList) > 3
        
        %=== Calculate receiver position ==================================
        [xyzdt sat_el sat_az sat_dop] = leastSquarePos(satPositions, ...
            navSolutions.channel.rawP  (activeChnList, currMeasNr)' + ...
            satClkCorr * settings.c, ...
            settings.c, settings.useTropCorr);
        navSolutions.channel.el(activeChnList, currMeasNr) = sat_el';
        navSolutions.channel.az (activeChnList, currMeasNr) = sat_az';
        navSolutions.DOP (:, currMeasNr) = sat_dop';
        %       %Transform from PZ90.02 to WGS84!
        %       xyz = xyzdt(1:3);
        %       xyz = [-1.1 -0.3 -0.9] + (1-0.12e-6).*([1 -0.82e-6 0; 0.82e-6 1 0; 0 0 1] * xyz')';
        %       xyzdt(1:3) = xyz;
        %
        %       navSolutions.channel.el(activeChnList, currMeasNr) = sat_el';
        %       navSolutions.channel.az (activeChnList, currMeasNr) = sat_az';
        %       navSolutions.DOP (:, currMeasNr) = sat_dop';
        
        %--- Save results -------------------------------------------------
        navSolutions.X (currMeasNr)  = xyzdt(1);
        navSolutions.Y (currMeasNr)  = xyzdt(2);
        navSolutions.Z (currMeasNr)  = xyzdt(3);
        navSolutions.dt(currMeasNr) = xyzdt(4);
        
        % Update the satellites elevations vector
        satElev = navSolutions.channel.el(:, currMeasNr);
        
        %=== Correct pseudorange measurements for clocks errors ===========
        navSolutions.channel.correctedP(activeChnList, currMeasNr) = ...
            navSolutions.channel.rawP  (activeChnList, currMeasNr) - ...
            satClkCorr' * settings.c + navSolutions.dt(currMeasNr);
        
        % Coordinate conversion ==================================================
        
        %=== Convert to geodetic coordinates ==============================
        [navSolutions.latitude(currMeasNr), ...
            navSolutions.longitude(currMeasNr), ...
            navSolutions.height(currMeasNr)] = cart2geo(...
            navSolutions.X (currMeasNr), ...
            navSolutions.Y (currMeasNr), ...
            navSolutions.Z (currMeasNr), ...
            5);
        
        %=== Convert to UTM coordinate system =============================
        navSolutions.utmZone  = findUtmZone(navSolutions.latitude(currMeasNr), ...
            navSolutions.longitude (currMeasNr));
        
        [navSolutions.E(currMeasNr), ...
            navSolutions.N(currMeasNr), ...
            navSolutions.U(currMeasNr)] = cart2utm(xyzdt(1), xyzdt(2), ...
            xyzdt(3), ...
            navSolutions.utmZone );
        
    else % if size(activeChnList, 2) > 3
        %--- There are not enough satellites to find 3D position ----------
        %/disp(['   Measurement No. ', num2str(currMeasNr), ...
        %/               ': Not enough information for position solution.']);
        
        %--- Set the missing solutions to NaN. These results will be
        %excluded automatically in all plots. For DOP it is easier to use
        %zeros. NaN values might need to be excluded from results in some
        %of further processing to obtain correct results.
        navSolutions.X (currMeasNr)           = nan;
        navSolutions.Y (currMeasNr)           = nan;
        navSolutions.Z (currMeasNr)           = nan;
        navSolutions.dt(currMeasNr)          = nan;
        navSolutions.DOP (:, currMeasNr)      = zeros(5, 1);
        navSolutions.latitude(currMeasNr)    = nan;
        navSolutions.longitude (currMeasNr)   = nan;
        navSolutions.height (currMeasNr)      = nan;
        navSolutions.E (currMeasNr)           = nan;
        navSolutions.N(currMeasNr)           = nan;
        navSolutions.U(currMeasNr)           = nan;
        
        navSolutions.channel.az (activeChnList, currMeasNr) = nan(length(activeChnList),1);
        navSolutions.channel.el(activeChnList, currMeasNr) = nan(length(activeChnList),1);
        
        % TODO: Know issue. Satellite positions are not updated if the
        % satellites are excluded do to elevation mask. Therefore raising
        % satellites will be not included even if they will be above
        % elevation mask at some point. This would be a good place to
        % update positions of the excluded satellites.
        
    end % if size(activeChnList, 2) > 3
    
    %=== Update the transmit time ("measurement time") ====================
    transmitTime = transmitTime + settings.navSolPeriod / 1000;
    
end %for currMeasNr...

% %Some trciks to speed up code. Structs are VERY SLOW in scilab 5.3.0.
% navSolutions.X                  = navSol_X;
% navSolutions.Y                  = navSol_Y;
% navSolutions.Z                  = navSol_Z;
% navSolutions.dt                 = navSol_dt;
% navSolutions.latitude           = navSol_latitude;
% navSolutions.longitude          = navSol_longitude;
% navSolutions.height             = navSol_height;
% navSolutions.utmZone            = navSol_UtmZone;
% navSolutions.E                  = navSol_E;
% navSolutions.N                  = navSol_N;
% navSolutions.U                  = navSol_U;
% navSolutions.DOP                = navSol_DOP;
% navSolutions.channel.SVN        = navSol_channel_SVN;
% navSolutions.channel.el         = navSol_channel_el;
% navSolutions.channel.az         = navSol_channel_az;
% navSolutions.channel.rawP       = navSol_channel_rawP;
% navSolutions.channel.correctedP = navSol_channel_corrP;

