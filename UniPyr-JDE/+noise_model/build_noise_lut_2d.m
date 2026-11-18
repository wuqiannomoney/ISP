function [lut_2d, Y_grid, g_grid] = build_noise_lut_2d(x_lut, gamma_lut, cfg)
% BUILD_NOISE_LUT_2D  离线/帧头生成 17x17 2D 噪声查表 Noise_LUT_2D(Y, g)
    NY = 17; NG = 17;
    Y_grid = linspace(0, 1, NY);
    g_grid = linspace(0.25, 6.0, NG);
    lut_2d = zeros(NY, NG);

    % 计算实际 Gamma 查找表的数值斜率 f'(x)
    dx = x_lut(2) - x_lut(1);
    gamma_deriv = gradient(gamma_lut, dx);

    % 防止自定义硬件 LUT 存在平段导致 interp1 报错
    [g_uniq, ia] = unique(gamma_lut, 'stable');
    x_uniq = x_lut(ia);

    for iy = 1:NY
        y_val = Y_grid(iy);
        x_post = interp1(g_uniq, x_uniq, y_val, 'linear', 'extrap');
        x_post = min(max(x_post, 0), 1);
        f_prime = interp1(x_lut, gamma_deriv, x_post, 'linear', 'extrap');

        for ig = 1:NG
            g_val = g_grid(ig);
            % f'(x_post) * sqrt(g * a * x_post + g^2 * b)
            sigma_lin_post = sqrt(max(g_val * cfg.a_iso * x_post + (g_val^2) * cfg.b_iso, 0));
            lut_2d(iy, ig) = f_prime * sigma_lin_post;
        end
    end
end