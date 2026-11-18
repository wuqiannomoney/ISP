function rgb_gamma = apply_gamma(rgb_lin, x_lut, gamma_lut)
% APPLY_GAMMA  使用 1D 查找表执行 Gamma 映射
    rgb_gamma = interp1(x_lut, gamma_lut, min(max(rgb_lin, 0), 1), 'linear');
end