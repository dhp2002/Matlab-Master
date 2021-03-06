function dps = get_das_peaks(im1,thresh)
% gpud = gpuDevice;
% amem = gpud.AvailableMemory;
amem = 4052352;
[m,n,o] = size(im1);
% calculate memory requirements
im1 = single(im1);
rows = numel(im1(:,1,1));
cols = numel(im1(1,:,1));
ims = numel(im1(1,1,:));

mem_size = rows*cols*ims*4;

if mem_size < amem              % if memory of the image is small enough, run it through
    dps = get_da_peaks(single(im1),thresh);
else                                                % If memory of image is too small, break it down into chunks and run it through the gpu
    chunks = ceil(mem_size / (amem));
    chunkim = floor(ims / chunks);
    for i = 1:chunks
        if i ~= chunks
%             i
            [dps_temp] = get_da_peaks(single(im1(:,:,1+(i-1)*chunkim:i*chunkim)),thresh);
            if i ==1
                dps = dps_temp;
                clear iprod_temp
            else
                dps = cat(3,dps, dps_temp);
                clear dps_temp 
            end
        else
            [dps_temp] = get_da_peaks(single(im1(:,:,1+(i-1)*chunkim:end)),thresh);
            dps = cat(3,dps,dps_temp);
            clear dps_temp
        end
    end
end