function sigma_maps = eval_pixel_sigma(I_guide_0, W_eff, G_LTM, lut_2d, Y_grid, g_grid, cfg)
% EVAL_PIXEL_SIGMA  方案2：查表得到基准噪声 sigma_0，按空间尺寸对齐并乘以实测层间标定系数

    Y_q = min(max(I_guide_0, 0), 1);
    g_q = min(max(G_LTM, g_grid(1)), g_grid(end));

    % 1. 查表获取 L0 尺度每个像素的基础单帧物理噪声标准差
    sigma_single = interp2(g_grid, Y_grid, lut_2d, g_q, Y_q, 'linear');

    % 2. 融合 3DNR 带来的噪声衰减
    N_eff_map = 1 + (cfg.max_3dnr_gain - 1) * min(max(W_eff, 0), 1);
    sigma_0 = sigma_single ./ sqrt(N_eff_map);
    % 理论稳态公式 sqrt((1-0.6*W_eff)/(1+0.6*W_eff))效果差不多

    % 3. 方案2核心：空间尺寸几何对齐 + 显式乘上实测的各层标定衰减系数 [s0, s1, s2]
    sigma_maps.s0 = sigma_0                   * cfg.layer_noise_scale(1);
    sigma_maps.s1 = sigma_0(1:2:end, 1:2:end) * cfg.layer_noise_scale(2);
    sigma_maps.s2 = sigma_0(1:4:end, 1:4:end) * cfg.layer_noise_scale(3);
end