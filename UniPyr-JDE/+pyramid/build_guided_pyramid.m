function pyr = build_guided_pyramid(YCgCo_in, sigma_maps, cfg)
% BUILD_GUIDED_PYRAMID  无 Loss 极简版：引导滤波保边平滑 + 标准拉普拉斯式残差 D0~D2
    [H, W, ~] = size(YCgCo_in);
    pyr.size0 = [H, W];

    % --- L0 (1x) ---
    eps_0 = cfg.gf_k(1) * (sigma_maps.s0 .^ 2);
    [S_0, pyr.a0] = pyramid.guided_filter_5x5_ycgco(YCgCo_in, eps_0);
    I_1 = ops.pyr_down_5tap(S_0);
    pyr.D0 = YCgCo_in - ops.pyr_up_5tap(I_1, [H, W]);

    % --- L1 (1/2x) ---
    [H1, W1, ~] = size(I_1);
    pyr.size1 = [H1, W1];
    eps_1 = cfg.gf_k(2) * (sigma_maps.s1 .^ 2);
    [S_1, pyr.a1] = pyramid.guided_filter_5x5_ycgco(I_1, eps_1);
    I_2 = ops.pyr_down_5tap(S_1);
    pyr.D1 = I_1 - ops.pyr_up_5tap(I_2, [H1, W1]);

    % --- L2 (1/4x) ---
    eps_2 = cfg.gf_k(3) * (sigma_maps.s2 .^ 2);
    [pyr.B2, pyr.a2] = pyramid.guided_filter_5x5_ycgco(I_2, eps_2);
    pyr.D2 = I_2 - pyr.B2;
end