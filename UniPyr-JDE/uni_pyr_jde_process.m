function [RGB_out, dbg] = uni_pyr_jde_process(RGB_in, W_eff, G_LTM, x_lut, gamma_lut, cfg)
% UNI_PYR_JDE_PROCESS  纯净单参数共享平滑架构：YCgCo 引导平滑降噪 -> 转 RGB 直接增强同一份 D_den

    %% 1. 入口转 1 次 YCgCo + 噪声场动态还原
    YCgCo_in  = ops.rgb2ycgco(RGB_in);
    I_guide_0 = YCgCo_in(:,:,1);

    [lut_2d, Y_grid, g_grid] = noise_model.build_noise_lut_2d(x_lut, gamma_lut, cfg);
    sigma_maps = noise_model.eval_pixel_sigma(I_guide_0, W_eff, G_LTM, lut_2d, Y_grid, g_grid, cfg);

    %% 2. 单参数引导滤波构建 3 层 5x5 共享金字塔 (无 Loss 版)
    pyr = pyramid.build_guided_pyramid(YCgCo_in, sigma_maps, cfg);

    %% 3. 在 YCgCo 域做跨层协同 Coring 降噪
    a_2_up1 = ops.pyr_up_5tap(pyr.a2, pyr.size1);
    a_1_up0 = ops.pyr_up_5tap(pyr.a1, pyr.size0);

    B2_luma   = pyr.B2(:,:,1);
    B2_luma_1 = ops.pyr_up_5tap(B2_luma, pyr.size1);
    B2_luma_0 = ops.pyr_up_5tap(B2_luma_1, pyr.size0);

    D_den.D2 = denoise.denoise_ycgco_layer(pyr.D2, sigma_maps.s2, pyr.a2, [], B2_luma, ...
                                           cfg.alpha_y(3), cfg.alpha_c(3), ...
                                           cfg.coring_damp_y, cfg.coring_damp_c, true);

    D_den.D1 = denoise.denoise_ycgco_layer(pyr.D1, sigma_maps.s1, pyr.a1, a_2_up1, B2_luma_1, ...
                                           cfg.alpha_y(2), cfg.alpha_c(2), ...
                                           cfg.coring_damp_y, cfg.coring_damp_c, true);

    D_den.D0 = denoise.denoise_ycgco_layer(pyr.D0, sigma_maps.s0, pyr.a0, a_1_up0, B2_luma_0, ...
                                           cfg.alpha_y(1), cfg.alpha_c(1), ...
                                           cfg.coring_damp_y, cfg.coring_damp_c, false);

    %% 4. 降噪结束：把基底 B2 和去噪后的 D_den 转回 RGB 域
    pyr_rgb.size0 = pyr.size0;
    pyr_rgb.size1 = pyr.size1;
    pyr_rgb.B2    = ops.ycgco2rgb(pyr.B2);

    D_den_rgb.D2  = ops.ycgco2rgb(D_den.D2);
    D_den_rgb.D1  = ops.ycgco2rgb(D_den.D1);
    D_den_rgb.D0  = ops.ycgco2rgb(D_den.D0);

    %% 5. 在 RGB 域直接对同一份 D_den_rgb 计算五重门控增益并重构 (100% 共享平滑层)
    iso_ratio = max(cfg.iso / cfg.iso_ref, 1.0);
    iso_decay = 1.0 / (1.0 + 0.15 * log2(iso_ratio));

    if cfg.max_3dnr_gain <= 1.0
        W_eff_gain = ones(size(W_eff));
    else
        W_eff_gain = W_eff;
    end
    W_eff_1 = ops.pyr_down_5tap(W_eff_gain);
    W_eff_2 = ops.pyr_down_5tap(W_eff_1);
    G_LTM_1 = ops.pyr_down_5tap(G_LTM);
    G_LTM_2 = ops.pyr_down_5tap(G_LTM_1);

    gains.G2 = enhance.compute_5fold_gain(cfg.base_gain_l(3), iso_decay, pyr.a2, [],      G_LTM_2, W_eff_2,    B2_luma);
    gains.G1 = enhance.compute_5fold_gain(cfg.base_gain_l(2), iso_decay, pyr.a1, a_2_up1, G_LTM_1, W_eff_1,    B2_luma_1);
    gains.G0 = enhance.compute_5fold_gain(cfg.base_gain_l(1), iso_decay, pyr.a0, a_1_up0, G_LTM,   W_eff_gain, B2_luma_0);
  gains.G2(:)=cfg.base_gain_l(3);
  gains.G1(:)=cfg.base_gain_l(2); 
  gains.G0(:)=cfg.base_gain_l(1);
    [RGB_denoised, Delta_enh] = pyramid.reconstruct_pyramid(pyr_rgb, D_den_rgb, gains);

    if cfg.usm_l0_strength > 0
        Delta_usm = enhance.apply_l0_usm(RGB_denoised, gains.G0, iso_decay, cfg);
        Delta_enh = Delta_enh + Delta_usm;
    end

    %% 6. RGB 域保色相软截断输出
    RGB_out = enhance.soft_clip_rgb(RGB_denoised, Delta_enh);

    %% 7. 调试诊断输出
    dbg.sigma_0    = sigma_maps.s0;
    dbg.a0         = pyr.a0;
    dbg.gain_map_0 = gains.G0;
    dbg.lut_2d     = lut_2d;
end