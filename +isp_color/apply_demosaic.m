function rgb = apply_demosaic(raw, pattern)
% APPLY_DEMOSAIC  5x5 Malvar-He-Cutler 高质量去马赛克（纯基础 MATLAB，零工具箱依赖）
    if nargin < 2 || isempty(pattern), pattern = 'gbrg'; end
    [H, W] = size(raw);
    raw = max(raw, 0);

    % 定义 Malvar 2004 5x5 核
    K_G = [ 0  0 -1  0  0;
            0  0  2  0  0;
           -1  2  4  2 -1;
            0  0  2  0  0;
            0  0 -1  0  0] / 8;

    K_H = [ 0  0  0.5 0  0;
            0 -1  0  -1  0;
           -1  4  5   4 -1;
            0 -1  0  -1  0;
            0  0  0.5 0  0] / 8;

    K_V = K_H';

    K_D = [ 0    0 -1.5 0  0;
            0    2  0   2  0;
           -1.5  0  6   0 -1.5;
            0    2  0   2  0;
            0    0 -1.5 0  0] / 8;

    p = ops.pad_rep(raw, 2, 2);
    f_G = conv2(p, K_G, 'valid');
    f_H = conv2(p, K_H, 'valid');
    f_V = conv2(p, K_V, 'valid');
    f_D = conv2(p, K_D, 'valid');

    % 按 Bayer 排布建立掩膜 (1:odd, 2:even)
    m_oo = false(H, W); m_oo(1:2:end, 1:2:end) = true;
    m_oe = false(H, W); m_oe(1:2:end, 2:2:end) = true;
    m_eo = false(H, W); m_eo(2:2:end, 1:2:end) = true;
    m_ee = false(H, W); m_ee(2:2:end, 2:2:end) = true;

    switch lower(pattern)
        case 'gbrg'
            m_Gb = m_oo; m_B = m_oe; m_R = m_eo; m_Gr = m_ee;
        case 'rggb'
            m_R = m_oo; m_Gr = m_oe; m_Gb = m_eo; m_B = m_ee;
        case 'bggr'
            m_B = m_oo; m_Gb = m_oe; m_Gr = m_eo; m_R = m_ee;
        case 'grbg'
            m_Gr = m_oo; m_R = m_oe; m_B = m_eo; m_Gb = m_ee;
        otherwise
            error('不支持的 Bayer 排布: %s', pattern);
    end

    R = zeros(H, W); G = zeros(H, W); B = zeros(H, W);

    % G 通道：Gr/Gb 保留原值，R/B 位置用 K_G 插值
    G(m_Gr | m_Gb) = raw(m_Gr | m_Gb);
    G(m_R  | m_B)  = f_G(m_R | m_B);

    % R 通道：Gr 处 R 在水平两侧 (K_H)，Gb 处 R 在垂直两侧 (K_V)，B 处用 K_D
    R(m_R)  = raw(m_R);
    R(m_Gr) = f_H(m_Gr);
    R(m_Gb) = f_V(m_Gb);
    R(m_B)  = f_D(m_B);

    % B 通道：Gb 处 B 在水平两侧 (K_H)，Gr 处 B 在垂直两侧 (K_V)，R 处用 K_D
    B(m_B)  = raw(m_B);
    B(m_Gb) = f_H(m_Gb);
    B(m_Gr) = f_V(m_Gr);
    B(m_R)  = f_D(m_R);

    rgb = min(max(cat(3, R, G, B), 0), 1);
end