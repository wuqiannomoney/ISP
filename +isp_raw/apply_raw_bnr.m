function raw_out = apply_raw_bnr(raw_in, W_eff, a_raw, b_raw, max_3dnr_gain, k_bnr)
% APPLY_RAW_BNR  受 W_eff 调制的 Bayer 同色 5x5 空域降噪（静态轻、运动重）
    if nargin < 6 || isempty(k_bnr), k_bnr = 2.0; end
    raw_out = zeros(size(raw_in));

    for r_off = 1:2
        for c_off = 1:2
            sub_p = raw_in(r_off:2:end, c_off:2:end);
            w_sub = W_eff(r_off:2:end, c_off:2:end);

            n_eff_sub = 1 + (max_3dnr_gain - 1) * min(max(w_sub, 0), 1);
            var_local = max(a_raw * max(sub_p, 0) + b_raw, 1e-10) ./ n_eff_sub;
            eps_map   = k_bnr * var_local;

            % 同色通道 5x5 高斯加权引导滤波
            mean_I  = ops.gauss5x5(sub_p);
            mean_II = ops.gauss5x5(sub_p .* sub_p);
            var_I   = max(mean_II - mean_I .* mean_I, 0);
            a_gf    = var_I ./ (var_I + eps_map + 1e-12);
            b_gf    = mean_I - a_gf .* mean_I;
            sub_gf  = ops.gauss5x5(a_gf) .* sub_p + ops.gauss5x5(b_gf);

            % 静止区保留更多原始微纹理，运动区 (w_sub->0) 强力激活 BNR 防迷宫纹
            blend_w = 1.0 - 0.80 * w_sub;
            raw_out(r_off:2:end, c_off:2:end) = (1 - blend_w) .* sub_p + blend_w .* sub_gf;
        end
    end

    % 经过 Raw 3DNR/BNR 抵消负噪声后，再安全截断负值进入 Demosaic
    raw_out = max(raw_out, 0);
end