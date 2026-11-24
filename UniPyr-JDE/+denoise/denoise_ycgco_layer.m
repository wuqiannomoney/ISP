function D_out = denoise_ycgco_layer(D_ycgco, sigma_map, a_curr, a_coarse_up, B2_luma, ...
                                     alpha_y, alpha_c, damp_y, damp_c, is_coarse_chroma)
% DENOISE_YCGCO_LAYER  基于单调结构置信度的 YCgCo 域统一 Coring 去噪
    D_out = zeros(size(D_ycgco));

    % 1. 平坦区自然拉升到 1.8x (覆盖 2.4~3.0σ)，真纹理区自然回落到 1.0x
    flat_boost = 1 + 0.8 * (1 - a_curr);

    % 2. 孤立尖峰抑制 (无粗层支撑时按 3.5σ 尖峰比例抬升门槛)
    if ~isempty(a_coarse_up)
        isolated_noise = max(a_curr - a_coarse_up, 0);
        cross_boost = 1 + 1.5 * isolated_noise;
    else
        cross_boost = 1.0;
    end

    % 3. sRGB 暗部线性趾区 (<0.12) 读出底噪保护
    dark_boost = 1 + 0.35 * max(1 - B2_luma / 0.12, 0);

    T_y = alpha_y * sigma_map .* flat_boost .* cross_boost .* dark_boost;
    d_y = D_ycgco(:,:,1);
    shrink_y = 1 - damp_y * exp(-0.5 * (d_y ./ max(T_y, 1e-6)).^2);
    D_out(:,:,1) = d_y .* shrink_y;

    if is_coarse_chroma
        % 强边缘处色度门限对称折半，防渗色的同时保持抗边缘彩噪能力
        edge_protect = 0.5 + 0.5 * (1 - a_curr);
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