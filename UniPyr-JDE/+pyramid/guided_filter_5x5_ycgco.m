function [S_ycgco, a_struct] = guided_filter_5x5_ycgco(YCgCo, eps_map)
% 为保证后续rgb增强不偏色，三个通道的eps以及系数a必须相同，
% 在正交ycocg下，这种条件的ycgco平滑和rgb平滑没有区别，选用ycocg是为了少转换，以及小计算均值
% GUIDED_FILTER_5X5_YCGCO  直接在 YCgCo 域执行的 5x5 高斯加权共用系数引导滤波
%   设计要点:
%     1) 零多余空间转换，直接在 YCgCo 计算各自局部均值与方差 (总计仅 10 次 gauss5x5)
%     2) var_edge = var_Y + 0.12*(var_Cg + var_Co): 既对齐亮度标定口径，又保住强纯色边缘
%     3) Y, Cg, Co 严格共用同一份结构权重 a_shared，保证后续 RGB 增强绝不偏色

    mean_P = cell(1, 3);
    var_P  = cell(1, 3);
    for c = 1:3
        P   = YCgCo(:,:,c);
        mP  = ops.gauss5x5(P);
        mPP = ops.gauss5x5(P .* P);
        mean_P{c} = mP;
        var_P{c}  = max(mPP - mP .* mP, 0);
    end

    % 联合结构方差
    var_edge = var_P{1} + 0.12 * (var_P{2} + var_P{3});

    % 三通道共用同一个权重系数 a_shared ∈ [0, 1]
    a_shared = var_edge ./ (var_edge + eps_map + 1e-12);
    a_struct = ops.gauss5x5(a_shared);

    S_ycgco = zeros(size(YCgCo));
    one_minus_a = 1.0 - a_shared;
    for c = 1:3
        b_c = one_minus_a .* mean_P{c};
        S_ycgco(:,:,c) = a_struct .* YCgCo(:,:,c) + ops.gauss5x5(b_c);
    end
end