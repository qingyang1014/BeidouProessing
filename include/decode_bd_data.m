function decoded_data = decode_bd_data(data)
% decode_bd_data used to decode data. It additionaly makes
% conversion from 1000 bits per second to 50 bits per second.
%
%decoded_data = decode_bd_data(data)
%
%   Inputs:
%       data            - output from the tracking function
%
%   Outputs:
%       decoded_data    - decoded subframe (10 data words)
%--------------------------------------------------------------------------
% Written by Artyom Gavrilov
%--------------------------------------------------------------------------

ndata = data(1:6000);

preamble = [1 1 1 -1 -1 -1 1 -1 -1 1 -1];%11bits
secondary_code = [-1 -1 -1 -1 -1 1 -1 -1 1 1 -1 1 -1 1 -1 -1 1 1 1 -1];%20bits
demod_data = kron(ones(1,300), secondary_code);

ndata = ndata .* demod_data; %Remove Neumann-Hoffman secondary code from data.

%Convert 20 bits to 1 bit.
ndata = reshape(ndata, 20, (length(ndata) / 20));
ndata = sum(ndata);
ndata = sign(ndata);

if (sign(sum(ndata(1:11).*preamble))==-1)
    ndata = -ndata;
end

decoded_data = ndata(12:26);
%deinterleave data:
for i = 1:9
    current_word = ndata(i*30+1 : i*30+30);
    decoded_data = [decoded_data current_word(1:2:21) current_word(2:2:22)];
end


