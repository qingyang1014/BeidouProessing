function showChannelStatus(channel, settings)
%Prints the status of all channels in a table.
%
%showChannelStatus(channel, settings)
%
%   Inputs:
%       channel     - data for each channel. It is used to initialize and
%                   at the processing of the signal (tracking part).
%       settings    - receiver settings

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

fprintf('\n*=========*=====*===============*===========*=============*========*\n');
fprintf('| Channel | PRN |   Frequency   |  Doppler  | Code Offset | Status |\n');
fprintf('*=========*=====*===============*===========*=============*========*\n');

for channelNr = 1 : settings.numberOfChannels
    if (channel(channelNr).status ~= '-')
        fprintf('|      %2d | %3d |  %12.0f |   %5.0f   |    %6d   |     %1s  |\n', ...
            channelNr, ...
            channel(channelNr).PRN, ...
            channel(channelNr).acquiredFreq, ...
            channel(channelNr).acquiredFreq - (settings.IF), ...
            channel(channelNr).codePhase, ...
            channel(channelNr).status);
    else
        fprintf('|      %2d | --- |  ------------ |   -----   |    ------   |   Off  |\n', ...
            channelNr);
    end
end

fprintf('*=========*=====*===============*===========*=============*========*\n\n');

