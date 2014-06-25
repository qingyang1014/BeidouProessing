function [FrameStart, activeChnList] = findSubframeStart(trackResults, settings)
% function [FrameStart, activeChnList] = findTimeMarks(trackResults, settings)
% findTimeMarks finds the first TimeMark occurrence in the bit stream of
% each channel. The TimeMark is a unique bit sequence!
% At the same time function returns list of channels, that are in
% tracking state.
%
%[firstSubFrame, activeChnList] = findTimeMarks(trackResults, settings)
%
%   Inputs:
%       trackResults      - output from the tracking function (trackResults)
%       settings          - output from the initSettings
%
%   Outputs:
%       FrameStart     - the array contains positions of the first
%                       time mark in each channel. The position is ms count
%                       since start of tracking. Corresponding value will
%                       be set to 0 if no valid preambles were detected in
%                       the channel.
%       activeChnList   - list of channels containing valid time marks
%--------------------------------------------------------------------------
% Written by Artyom Gavrilov
% Updated and converted to matlab by Xiangyu Li
%--------------------------------------------------------------------------

%--- Make a list of channels excluding not tracking channels --------------
FrameStart = [];
delFromActiveChnList = [];
activeChnList = find([trackResults.status] ~= '-');

%=== For all tracking channels ...
for channelNr = activeChnList
    
    nav_bits = sign(trackResults(channelNr).I_P(1 : end)); 
    %nav_bits = sign( trkRslt_I_P(channelNr, 1:end) ); %convert to +-1.
    
    %COMPASS B1 Preamble and secondary code. Bits order is reversed!
    preamble_bits = [-1 1 -1 -1 1 -1 -1 -1 1 1 1];
    secondary_code = [-1 1 1 1 -1 -1 1 -1 1 -1 1 1 -1 -1 1 -1 -1 -1 -1 -1];
    preamble_long = kron(preamble_bits, -secondary_code); %Preamble on sampling frequency 1000 Hz!
    preamble_corr_rslt = conv(preamble_long, nav_bits);%Convolution is used here
    % instead of correlation. Just it
    % was easier for me! In fact we
    % calculate correlation because
    % we use inverse-order Preamble in convolution.
    preamble_corr_rslt = preamble_corr_rslt(220:length(preamble_corr_rslt)); %First 220 points are of no interest!
    
    %normal 200; for debugging use 100
    index = find( abs(preamble_corr_rslt) > 60)'; %Find places where
    % correlation-result is high
    % enough! These points correspond
    % to the first point of Preamble.
    %pause;
    % If we have not found preamble - remove sat from the list:
    if isempty(index) 
        delFromActiveChnList = [delFromActiveChnList channelNr];
    else
        FrameStart(channelNr) = index(1);
    end
    
end

activeChnList = setdiff(activeChnList, delFromActiveChnList);


