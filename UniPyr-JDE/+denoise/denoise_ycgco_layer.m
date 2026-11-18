function D_out = denoise_ycgco_layer(D_ycgco, sigma_map, a_curr, a_coarse_up, B2_luma, ...
                                     alpha_y, alpha_c, damp_y, damp_c, is_coarse_chroma)
% DENOISE_YCGCO_LAYER  YCgCo 域结合本层/粗层置信度与基底保护的平滑 Coring 去噪
    D_out = zeros(size(D_ycgco));

    % 1. 平坦区强化压制 (a_curr -> 0)
    flat_boost = 1 + 0.6 * (1 - a_curr);

    % 2. 跨尺度结构裁决 (本层高但粗层无支撑 -> 判定为孤立粗噪点，提高阈值)
    if ~isempty(a_coarse_up)
        isolated_noise = max(a_curr - a_coarse_up, 0);
        cross_boost = 1 + 0.8 * isolated_noise;
    else
        cross_boost = 1.0;
    end

    % 3. 最粗基底暗部防护
    dark_boost = 1 + 0.35 * max(1 - B2_luma / 0.12, 0);

    % --- 亮度 Y 通道平滑指数收缩 ---
    T_y = alpha_y * sigma_map .* flat_boost .* cross_boost .* dark_boost;
    d_y = D_ycgco(:,:,1);
    shrink_y = 1 - damp_y * exp(-0.5 * (d_y ./ max(T_y, 1e-6)).^2);
    D_out(:,:,1) = d_y .* shrink_y;

    % --- 色度 Cg / Co 通道去噪 (带亮度边缘防渗色保护) ---
    if is_coarse_chroma
        edge_protect = 0.25 + 0.75 * (1 - a_curr);
    else
        edge_protect = 1.0;
    end
    T_c = alpha_c * sigma_map .* flat_boost .* dark_boost .* edge_protect;

    for ch = 2:3
        d_c = D_ycgco(:,:,ch);
        shrink_c = 1 - damp_c * exp(-0.5 * (d_c ./ max(T_c, 1e-6)).^2);
        D_out(:,:,ch) = d_c .* shrink_c;
    end
end