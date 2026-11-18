function [RGB_denoised, Delta_enh] = reconstruct_pyramid(pyr, D_den, gains)
% RECONSTRUCT_PYRAMID  无 Loss 标准拉普拉斯式无损重构
    % 1) 纯去噪图重构
    R2_den = pyr.B2 + D_den.D2;
    R1_den = ops.pyr_up_5tap(R2_den, pyr.size1) + D_den.D1;
    RGB_denoised = ops.pyr_up_5tap(R1_den, pyr.size0) + D_den.D0;

    % 2) 增强增量逐级上采样累加
    Enh2 = (gains.G2 - 1) .* D_den.D2;
    Enh1 = ops.pyr_up_5tap(Enh2, pyr.size1) + (gains.G1 - 1) .* D_den.D1;
    Delta_enh = ops.pyr_up_5tap(Enh1, pyr.size0) + (gains.G0 - 1) .* D_den.D0;
end