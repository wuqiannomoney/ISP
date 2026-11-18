function raw = read_crvd_tiff(tiff_path)
% READ_CRVD_TIFF  读取 CRVD 12-bit Raw .tiff 图像为 double 矩阵
    raw = double(imread(tiff_path));
    if ndims(raw) > 2
        raw = raw(:,:,1);
    end
end