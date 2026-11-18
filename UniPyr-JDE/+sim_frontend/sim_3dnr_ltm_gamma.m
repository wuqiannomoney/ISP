function [RGB_gamma, W_eff, G_LTM, RGB_gt_gamma] = sim_3dnr_ltm_gamma(RGB_clean_lin, mask_obj, x_lut, gamma_lut, cfg)
% SIM_3DNR_LTM_GAMMA  模拟 Raw 3DNR 残差噪声、独立线性对数 LTM 与 Gamma
    [H, W, ~] = size(RGB_clean_lin);

    % 1. 构造 3DNR 有效融合置信度图 W_eff (运动圆环内为 0，背景为 0.95)
    W_eff = 0.95 * ones(H, W);
    W_eff(mask_obj) = 0.0;
    W_eff = ops.gauss5x5(ops.gauss5x5(W_eff));

    % 2. 注入物理泊松-高斯噪声
    N_eff_map = 1 + (cfg.max_3dnr_gain - 1) * W_eff;
    noise_std_lin = sqrt((cfg.a_iso * RGB_clean_lin + cfg.b_iso) ./ N_eff_map);
    RGB_noisy_lin = max(RGB_clean_lin + noise_std_lin .* randn(size(RGB_clean_lin)), 1e-5);

    % 3. 模拟线性域对数 LTM (记录每层尺寸，逐级下采样再逐级上采样)
    L_lin = 0.299*RGB_noisy_lin(:,:,1) + 0.587*RGB_noisy_lin(:,:,2) + 0.114*RGB_noisy_lin(:,:,3);
    B_log = log(max(L_lin, 1e-4));

    n_levels = 6;
    sz_hist = cell(n_levels, 1);
    for it = 1:n_levels
        sz_hist{it} = size(B_log);
        B_log = ops.pyr_down_5tap(B_log);
    end
    for it = n_levels:-1:1
        B_log = ops.pyr_up_5tap(B_log, sz_hist{it}(1:2));
    end

    B_lin = exp(B_log);
    B_target = (B_lin ./ (B_lin + 0.15)) * 1.15;
    G_LTM = min(max(B_target ./ max(B_lin, 1e-4), 0.5), 4.5);

    RGB_ltm_noisy = min(max(RGB_noisy_lin .* G_LTM, 0), 1);
    RGB_ltm_clean = min(max(RGB_clean_lin .* G_LTM, 0), 1);

    % 4. 过 Gamma 查找表
    RGB_gamma    = interp1(x_lut, gamma_lut, RGB_ltm_noisy, 'linear');
    RGB_gt_gamma = interp1(x_lut, gamma_lut, RGB_ltm_clean, 'linear');
end