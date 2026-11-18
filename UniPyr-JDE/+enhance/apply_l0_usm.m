function Delta_usm = apply_l0_usm(RGB_denoised, Gain_0, iso_decay, cfg)
% APPLY_L0_USM  可选 L0 轻量 3x3 USM 边缘锐化 (复用 L0 门控并限幅防过冲)
    [H, W, ~] = size(RGB_denoised);
    k3 = [1 2 1; 2 4 2; 1 2 1] / 16;
    p_den = ops.pad_rep(RGB_denoised, 1, 1);

    blur3 = zeros(H, W, 3);
    for c = 1:3
        blur3(:,:,c) = conv2(p_den(:,:,c), k3, 'valid');
    end

    usm_diff = RGB_denoised - blur3;
    lim = cfg.usm_max_overshoot;
    usm_diff = min(max(usm_diff, -lim), lim);

    gate_0 = (Gain_0 - 1) ./ max(cfg.base_gain_l(1) - 1, 1e-6);
    Delta_usm = cfg.usm_l0_strength * iso_decay * gate_0 .* usm_diff;
end