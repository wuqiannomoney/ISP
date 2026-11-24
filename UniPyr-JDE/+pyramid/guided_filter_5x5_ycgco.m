function [S_ycgco, a_struct] = guided_filter_5x5_ycgco(YCgCo, eps_smooth, eps_detect)
% GUIDED_FILTER_5X5_YCGCO  平滑阈值(eps_smooth)与结构检测阈值(eps_detect)解耦的 5x5 引导滤波
%   设计要点:
%     1) var_edge 只算一次，零多余卷积开销
%     2) eps_detect 锁定物理噪声尺度，保住真实纹理的 a_struct 不被大 gf_k 压塌
%     3) eps_smooth 使用较大 gf_k，让中等纹理顺利进 D 层增强，同时超强边依然留在 S 层防光晕

    if nargin < 3 || isempty(eps_detect)
        eps_detect = eps_smooth;
    end

    mean_P = cell(1, 3);
    var_P  = cell(1, 3);
    for c = 1:3
        P   = YCgCo(:,:,c);
        mP  = ops.gauss5x5(P);
        mPP = ops.gauss5x5(P .* P);
        mean_P{c} = mP;
        var_P{c}  = max(mPP - mP .* mP, 0);
    end

    % 全彩联合结构方差
    var_edge = var_P{1} + 0.12 * (var_P{2} + var_P{3});

    % 1) 用固定噪声尺度 eps_detect 计算结构置信度图 a_struct
    a_detect = var_edge ./ (var_edge + eps_detect + 1e-12);
    a_struct = ops.gauss5x5(a_detect);

    % 2) 用较大平滑尺度 eps_smooth 计算平滑混合权重 a_smooth
    a_smooth      = var_edge ./ (var_edge + eps_smooth + 1e-12);
    a_smooth_mean = ops.gauss5x5(a_smooth);

    % 3) 三通道共用平滑权重混合各自原图与局部均值
    S_ycgco = zeros(size(YCgCo));
    one_minus_a = 1.0 - a_smooth;
    for c = 1:3
        b_c = one_minus_a .* mean_P{c};
        S_ycgco(:,:,c) = a_smooth_mean .* YCgCo(:,:,c) + ops.gauss5x5(b_c);
    end
end