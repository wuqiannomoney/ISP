function Gain = compute_5fold_gain(base_gain, iso_decay, a_curr, a_coarse_up, G_ltm, W_eff, B2_luma)
% COMPUTE_5FOLD_GAIN  计算五重门控调制后的增强增益图
    % 1) 本层及跨层结构门控 (防平坦区放大噪点，强阶跃边防白边过冲)
    m_struct = min(max((a_curr - 0.12) / 0.35, 0), 1);
    m_overshoot = 1 - 0.5 * min(max((a_curr - 0.88) / 0.12, 0), 1);
    m_struct = m_struct .* m_overshoot;
    if ~isempty(a_coarse_up)
        m_cross = 0.45 + 0.55 * min(max(a_coarse_up / 0.30, 0), 1);
        m_struct = m_struct .* m_cross;
    end

    % 2) LTM 强提亮暗区保护
    m_ltm = 1 ./ (1 + (max(G_ltm - 1.3, 0) / 1.5).^2);

    % 3) 3DNR 运动退化区保护
    m_3dnr = 0.35 + 0.65 * min(max(W_eff, 0), 1);

    % 4) 最粗基底亮暗边界护栏
    m_dark = min(max((B2_luma - 0.02) / 0.08, 0.15), 1);
    m_bright = min(max((0.98 - B2_luma) / 0.12, 0.2), 1);
    m_luma = m_dark .* m_bright;

    Gain = 1 + (base_gain - 1) * iso_decay .* m_struct .* m_ltm .* m_3dnr .* m_luma;
end