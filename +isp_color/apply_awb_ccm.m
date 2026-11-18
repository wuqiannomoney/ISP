function [rgb_lin, wb_gain, ccm] = apply_awb_ccm(rgb_in, wb_gain, ccm)
% APPLY_AWB_CCM  线性域白平衡增益 + 3x3 色彩校正矩阵
    if nargin < 2 || isempty(wb_gain)
        % Gray-World 自动估计白平衡（仅做标定/测试时建议先由 clean 图算好后复用给 noisy 图）
        mR = mean(mean(rgb_in(:,:,1)));
        mG = mean(mean(rgb_in(:,:,2)));
        mB = mean(mean(rgb_in(:,:,3)));
        wb_gain = [mG / max(mR, 1e-6), 1.0, mG / max(mB, 1e-6)];
        wb_gain = min(max(wb_gain, 0.5), 4.0);
    end
    if nargin < 3 || isempty(ccm)
        % 标准 CMOS 典型 sRGB CCM（行和为 1.0，保持中性灰不偏色）
        ccm = [ 1.60, -0.45, -0.15;
               -0.20,  1.45, -0.25;
               -0.05, -0.45,  1.50 ];
    end

    rgb_wb = zeros(size(rgb_in));
    for c = 1:3
        rgb_wb(:,:,c) = min(max(rgb_in(:,:,c) * wb_gain(c), 0), 1);
    end

    [H, W, ~] = size(rgb_wb);
    flat = reshape(rgb_wb, H*W, 3);
    flat_ccm = flat * ccm';
    rgb_lin = min(max(reshape(flat_ccm, H, W, 3), 0), 1);
end